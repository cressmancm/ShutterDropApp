import CoreGraphics
import Foundation
import SwiftData

/// Fills in a new post: the photo's details, a place name when Location
/// Lookups is on, Vision's labels and the alt text.
///
/// It coordinates from the main actor, where the post lives, but the heavy
/// work happens elsewhere: decoding runs in `PhotoDetailsReader.load`, filename
/// lookups in `PhotoLibrary.filename(assetID:)`, Vision and Apple
/// Intelligence in `ImageAnalyzer`, and place names in `LocationNamer`.
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

        if AppSettings.lookupsEnabled, let latitude = post.latitude, let longitude = post.longitude {
            post.location = await LocationNamer.placeName(latitude: latitude, longitude: longitude) ?? ""
        }

        if let preview {
            let labels = await analyzer.labels(for: preview)
            post.sceneLabels = labels.scene
            if AppSettings.writesAltText {
                post.altText = await analyzer.altText(for: preview, context: context(for: post, labels: labels)) ?? post.altText
            }
        } else {
            Log.photos.error("Couldn't decode \(post.filename, privacy: .private) for Vision")
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
        if let text = await analyzer.altText(for: preview, context: context(for: post, labels: labels)) {
            post.altText = text
        }
    }

    /// Looks up the place name again, for a post whose location is empty after
    /// Location Lookups was turned on.
    func lookUpPlace(for post: Post) async {
        guard let latitude = post.latitude, let longitude = post.longitude else { return }
        if let name = await LocationNamer.placeName(latitude: latitude, longitude: longitude) {
            post.location = name
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

    private func context(for post: Post, labels: ImageAnalyzer.Labels) -> ImageAnalyzer.Context {
        ImageAnalyzer.Context(
            place: post.location,
            camera: post.cameraLine,
            focalLength: post.focalLength,
            shutter: post.shutter,
            labels: labels
        )
    }
}
