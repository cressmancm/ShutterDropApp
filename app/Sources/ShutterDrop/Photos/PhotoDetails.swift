import CoreGraphics
import Foundation
import ImageIO

/// What a photo's own metadata says about how it was taken.
struct PhotoDetails: Sendable, Equatable {
    var cameraModel = ""
    var lensModel = ""
    var iso: Double?
    var focalLength: Double?
    var aperture: Double?
    var shutter: Double?
    var dateTaken: Date?
    var latitude: Double?
    var longitude: Double?
}

/// Reads photo details and makes the smaller copy Vision and Apple
/// Intelligence look at. Ported from the old skill's photometa.swift.
enum PhotoDetailsReader {
    /// The longest side of the copy the on-device models see.
    static let previewSize = 1568

    static func read(from data: Data) -> PhotoDetails {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return PhotoDetails() }
        return read(properties: properties)
    }

    static func read(properties: [CFString: Any]) -> PhotoDetails {
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]

        var details = PhotoDetails()
        details.cameraModel = (tiff[kCGImagePropertyTIFFModel] as? String)?.trimmed ?? ""
        details.lensModel = (exif[kCGImagePropertyExifLensModel] as? String)?.trimmed ?? ""
        details.iso = (exif[kCGImagePropertyExifISOSpeedRatings] as? [Double])?.first
        details.focalLength = exif[kCGImagePropertyExifFocalLength] as? Double
        details.aperture = exif[kCGImagePropertyExifFNumber] as? Double
        details.shutter = exif[kCGImagePropertyExifExposureTime] as? Double
        details.dateTaken = date(
            exif[kCGImagePropertyExifDateTimeOriginal] as? String,
            offset: exif[kCGImagePropertyExifOffsetTimeOriginal] as? String
        )
        if let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
           let longitude = gps[kCGImagePropertyGPSLongitude] as? Double {
            let south = (gps[kCGImagePropertyGPSLatitudeRef] as? String) == "S"
            let west = (gps[kCGImagePropertyGPSLongitudeRef] as? String) == "W"
            details.latitude = south ? -latitude : latitude
            details.longitude = west ? -longitude : longitude
        }
        return details
    }

    /// The photo upright and no larger than `maxPixelSize` on its longest side.
    /// Large 16-bit TIFFs that the thumbnail path can't handle fall back to the
    /// full image.
    static func previewImage(from data: Data, maxPixelSize: Int = previewSize) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            ?? CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// EXIF dates read "2025:03:01 17:42:10", with the time zone kept apart.
    private static func date(_ text: String?, offset: String?) -> Date? {
        guard let text else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let offset {
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"
            if let date = formatter.date(from: text + offset) { return date }
        }
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: text)
    }
}
