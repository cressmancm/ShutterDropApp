import CoreGraphics
import Foundation
import SwiftData

/// Fills in a new post: the photo's details, Vision's labels, a place name
/// when Location Lookups is on, and the alt text and hashtag ideas.
///
/// It coordinates from the main actor, where the post lives, but the heavy
/// work happens elsewhere: decoding runs in `PhotoDetailsReader.load`, filename
/// lookups in `PhotoLibrary.filename(assetID:)`, Vision and Apple
/// Intelligence (on device or on Private Cloud Compute) in `ImageAnalyzer`,
/// and place names in `LocationNamer`.
@MainActor
final class PostProcessor {
    private let library: PhotoLibrary
    private let analyzer = ImageAnalyzer()

    init(library: PhotoLibrary) {
        self.library = library
    }

    func process(_ post: Post) async {
        let clock = ContinuousClock()
        let start = clock.now
        guard let data = await imageData(for: post) else {
            Log.photos.error("Couldn't load the image for \(post.assetID, privacy: .private); will try again next time")
            return
        }
        if post.filename.isEmpty, post.localImageName == nil {
            post.filename = await PhotoLibrary.filename(assetID: post.assetID)
        }

        var (details, preview) = await PhotoDetailsReader.load(data)
        if let asset = library.asset(withID: post.assetID) {
            // Photos' own date and place win over the file's, as in the old skill.
            details.dateTaken = asset.creationDate ?? details.dateTaken
            if let location = asset.location {
                details.latitude = location.coordinate.latitude
                details.longitude = location.coordinate.longitude
            }
        }
        post.apply(details)
        Log.photos.info("Read \(post.filename, privacy: .private): \(post.cameraLine.isEmpty ? "no camera" : "camera found", privacy: .public), \(post.latitude == nil ? "no GPS" : "GPS", privacy: .public), \(data.count / 1_000_000, privacy: .public) MB")

        // Vision first: what it sees helps MapKit find the place the photo shows.
        var labels = ImageAnalyzer.Labels()
        if let preview {
            labels = await analyzer.labels(for: preview)
            post.sceneLabels = labels.scene
        } else {
            Log.photos.error("Couldn't decode \(post.filename, privacy: .private) for Vision")
        }

        var place: LocationNamer.Place?
        if AppSettings.lookupsEnabled, let latitude = post.latitude, let longitude = post.longitude {
            place = await LocationNamer.place(latitude: latitude, longitude: longitude, sceneLabels: labels.scene)
            post.location = place?.name ?? ""
        }

        if let preview {
            await describe(post, image: preview, labels: labels, place: place)
        }
        post.processedAt = .now
        Log.photos.info("Finished \(post.filename, privacy: .private) in \((clock.now - start).logText, privacy: .public)")
    }

    /// Writes fresh alt text for a post, for the Write and Regenerate buttons
    /// and for filling in posts that came in while it couldn't run.
    func regenerateAltText(for post: Post) async {
        guard let data = await imageData(for: post),
              let preview = await PhotoDetailsReader.load(data).preview
        else {
            Log.altText.error("Couldn't load \(post.filename, privacy: .private) to write alt text")
            return
        }
        let labels = await analyzer.labels(for: preview)
        let context = context(for: post, labels: labels, place: nil)
        if let draft = await analyzer.draft(for: preview, context: context), let text = draft.altText.trimmed.nilIfEmpty {
            post.altText = text
        } else if let text = await analyzer.altText(for: preview, context: context) {
            post.altText = text
        }
    }

    /// Looks up the place name again, for a post whose location is empty after
    /// Location Lookups was turned on.
    func lookUpPlace(for post: Post) async {
        guard let latitude = post.latitude, let longitude = post.longitude else { return }
        if let name = await LocationNamer.place(latitude: latitude, longitude: longitude, sceneLabels: post.sceneLabels)?.name {
            post.location = name
        }
    }

    /// Fills in the alt text, and with Private Cloud Compute the place the
    /// photo shows and hashtag ideas. Without it, the on-device model writes
    /// the alt text and MapKit's place name stands.
    private func describe(_ post: Post, image: CGImage, labels: ImageAnalyzer.Labels, place: LocationNamer.Place?) async {
        let context = context(for: post, labels: labels, place: place)
        if let draft = await analyzer.draft(for: image, context: context) {
            // The place comes from the photo plus MapKit, so only when the
            // user allows location lookups.
            if AppSettings.lookupsEnabled, post.latitude != nil, let landmark = draft.landmark.trimmed.nilIfEmpty {
                post.location = LocationNamer.compose(place: landmark, city: place?.city) ?? post.location
            }
            post.suggestedHashtags = Hashtags.extract(from: draft.hashtags.joined(separator: " "))
            if AppSettings.altTextEnabled, let text = draft.altText.trimmed.nilIfEmpty {
                post.altText = text
            }
            return
        }
        if AppSettings.writesAltText {
            post.altText = await analyzer.altText(for: image, context: context) ?? post.altText
        }
    }

    func imageData(for post: Post) async -> Data? {
        if let name = post.localImageName {
            return LocalImageStore.data(named: name)
        }
        guard let asset = library.asset(withID: post.assetID) else { return nil }
        do {
            return try await library.imageData(for: asset)
        } catch {
            Log.photos.error("Photos couldn't deliver \(post.assetID, privacy: .private): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func context(for post: Post, labels: ImageAnalyzer.Labels, place: LocationNamer.Place?) -> ImageAnalyzer.Context {
        ImageAnalyzer.Context(
            place: post.location,
            city: place?.city ?? "",
            nearby: place?.nearby.map(\.line) ?? [],
            light: post.sun?.description ?? "",
            date: post.dateText,
            labels: labels
        )
    }
}
