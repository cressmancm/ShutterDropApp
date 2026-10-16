import Foundation
import SwiftData

/// One photo on its way to Instagram: the details read from the photo, what the
/// user typed, and whether it's been posted. Every field the user sees is
/// editable for this post; the layout comes from the post template in Settings.
@Model
final class Post {
    /// Where the photo came from.
    enum Source: String, Codable {
        /// The ShutterDrop album in Photos, scanned each time the app opens.
        case album
        /// Chosen with the photo picker, without library access.
        case picker
        /// A row from the old ShutterDrop.numbers sheet with no matching photo.
        case imported
    }

    /// The photo's Photos library ID. Imported rows with no photo get a
    /// made-up ID so the field stays unique.
    @Attribute(.unique) var assetID: String
    var sourceRaw: String
    var filename: String
    /// When the photo was taken; the queue sorts on it, newest first.
    var dateTaken: Date?
    /// When ShutterDrop first saw the photo.
    var addedAt: Date

    var caption: String
    var location: String
    var cameraModel: String
    var lensModel: String
    /// "Model with Lens", editable on its own.
    var cameraLine: String
    var iso: String
    var focalLength: String
    var aperture: String
    var shutter: String
    /// "125 ISO | 340 mm | f/6 | 1/125 s", editable on its own.
    var exposure: String
    /// "Month Day, Year", editable on its own.
    var dateText: String
    var hashtags: String
    var altText: String

    var isPosted: Bool
    var postedAt: Date?

    /// The photo's GPS position, kept so a place name can be looked up later.
    var latitude: Double?
    var longitude: Double?
    /// Vision's top scene labels, for the hashtag search term.
    var sceneLabels: [String]

    /// For a photo chosen with the picker: the copy ShutterDrop keeps, since it
    /// can't read the photo from the library later.
    var localImageName: String?
    /// When the photo's details, place name and alt text were filled in.
    var processedAt: Date?

    var source: Source {
        get { Source(rawValue: sourceRaw) ?? .album }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        assetID: String,
        source: Source,
        filename: String = "",
        dateTaken: Date? = nil,
        addedAt: Date = .now
    ) {
        self.assetID = assetID
        self.sourceRaw = source.rawValue
        self.filename = filename
        self.dateTaken = dateTaken
        self.addedAt = addedAt
        self.caption = ""
        self.location = ""
        self.cameraModel = ""
        self.lensModel = ""
        self.cameraLine = ""
        self.iso = ""
        self.focalLength = ""
        self.aperture = ""
        self.shutter = ""
        self.exposure = ""
        self.dateText = dateTaken.map(PostFormat.date) ?? ""
        self.hashtags = ""
        self.altText = ""
        self.isPosted = false
        self.postedAt = nil
        self.latitude = nil
        self.longitude = nil
        self.sceneLabels = []
        self.localImageName = nil
        self.processedAt = nil
    }
}

extension Post {
    /// The values the post template fills its tags with.
    var templateValues: PostTemplate.Values {
        PostTemplate.Values(
            caption: caption,
            location: location,
            camera: cameraModel,
            lens: lensModel,
            cameraWithLens: cameraLine,
            exposure: exposure,
            iso: iso,
            focalLength: focalLength,
            aperture: aperture,
            shutter: shutter,
            date: dateText,
            hashtags: hashtags
        )
    }

    /// The finished post, laid out by `template`.
    func render(with template: String) -> String {
        PostTemplate.render(template, values: templateValues)
    }

    func setPosted(_ posted: Bool, at date: Date = .now) {
        isPosted = posted
        postedAt = posted ? date : nil
    }

    /// Fills in what was read from the photo, formatted the way posts show it.
    func apply(_ details: PhotoDetails) {
        cameraModel = details.cameraModel
        lensModel = details.lensModel
        cameraLine = PostFormat.cameraLine(model: details.cameraModel, lens: details.lensModel)
        iso = PostFormat.iso(details.iso)
        focalLength = PostFormat.focalLength(details.focalLength)
        aperture = PostFormat.aperture(details.aperture)
        shutter = PostFormat.shutter(details.shutter)
        exposure = PostFormat.exposure(iso: iso, focalLength: focalLength, aperture: aperture, shutter: shutter)
        if let taken = details.dateTaken {
            dateTaken = taken
            dateText = PostFormat.date(taken)
        }
        latitude = details.latitude
        longitude = details.longitude
    }
}
