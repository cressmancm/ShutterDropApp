import CoreGraphics
import Foundation
import SwiftData

/// Fills in a new post: the photo's details, a place name when Location
/// Lookups is on, Vision's labels and the alt text.
@MainActor
final class PostProcessor {
    private let library: PhotoLibrary
    private let analyzer = ImageAnalyzer()

    init(library: PhotoLibrary) {
        self.library = library
    }

    func process(_ post: Post) async {
        guard let data = await imageData(for: post) else { return }

        var details = PhotoDetailsReader.read(from: data)
        if let asset = library.asset(withID: post.assetID) {
            // Photos' own date and place win over the file's, as in the old skill.
            details.dateTaken = asset.creationDate ?? details.dateTaken
            if let location = asset.location {
                details.latitude = location.coordinate.latitude
                details.longitude = location.coordinate.longitude
            }
        }
        post.apply(details)

        if AppSettings.lookupsEnabled, let latitude = post.latitude, let longitude = post.longitude {
            post.location = await LocationNamer.placeName(latitude: latitude, longitude: longitude) ?? ""
        }

        if let preview = PhotoDetailsReader.previewImage(from: data) {
            let labels = await analyzer.labels(for: preview)
            post.sceneLabels = labels.scene
            if AppSettings.writesAltText {
                post.altText = await analyzer.altText(for: preview, context: context(for: post, labels: labels)) ?? post.altText
            }
        }
        post.processedAt = .now
    }

    /// Writes fresh alt text for a post, for the Write and Regenerate buttons
    /// and for filling in posts that came in while it couldn't run.
    func regenerateAltText(for post: Post) async {
        guard let data = await imageData(for: post),
              let preview = PhotoDetailsReader.previewImage(from: data)
        else { return }
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
        return try? await library.imageData(for: asset)
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
