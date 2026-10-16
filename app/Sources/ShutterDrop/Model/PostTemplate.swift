import Foundation

/// Lays out a post from a template of fixed text, emojis, line breaks and
/// `{template tags}`.
///
/// A line whose tags are all empty is left out, emojis and fixed words with it;
/// that's how the 📍 line disappears when a photo has no location. Blank lines
/// left behind collapse to one, and the post never starts or ends blank.
enum PostTemplate {
    static let defaultText = """
        {caption}

        📍 {location}
        📷 Shot on {camera_with_lens}
        🎆 {exposure}
        📅 {date}
        🎨 Edited in Lightroom CC

        {hashtags}
        """

    /// Every tag the template understands, in the order Settings shows them.
    enum Tag: String, CaseIterable, Sendable {
        case caption
        case location
        case camera
        case lens
        case cameraWithLens = "camera_with_lens"
        case exposure
        case iso
        case focalLength = "focal_length"
        case aperture
        case shutter
        case date
        case hashtags

        /// The tag as it's written in a template: `{camera_with_lens}`.
        var token: String { "{\(rawValue)}" }
    }

    struct Values: Sendable, Equatable {
        var caption = ""
        var location = ""
        var camera = ""
        var lens = ""
        var cameraWithLens = ""
        var exposure = ""
        var iso = ""
        var focalLength = ""
        var aperture = ""
        var shutter = ""
        var date = ""
        var hashtags = ""

        func value(for tag: Tag) -> String {
            switch tag {
            case .caption: caption
            case .location: location
            case .camera: camera
            case .lens: lens
            case .cameraWithLens: cameraWithLens
            case .exposure: exposure
            case .iso: iso
            case .focalLength: focalLength
            case .aperture: aperture
            case .shutter: shutter
            case .date: date
            case .hashtags: hashtags
            }
        }
    }

    static func render(_ template: String, values: Values) -> String {
        var lines: [String] = []
        for line in template.components(separatedBy: "\n") {
            let tags = tags(in: line)
            let filled = tags.filter { !values.value(for: $0).trimmed.isEmpty }
            if !tags.isEmpty && filled.isEmpty { continue }

            var rendered = line
            for tag in tags {
                rendered = rendered.replacingOccurrences(of: tag.token, with: values.value(for: tag).trimmed)
            }
            lines.append(rendered)
        }
        return collapseBlankLines(lines).joined(separator: "\n")
    }

    /// The known tags on one line. Anything else in braces stays as typed.
    static func tags(in line: String) -> [Tag] {
        Tag.allCases.filter { line.contains($0.token) }
    }

    private static func collapseBlankLines(_ lines: [String]) -> [String] {
        var result: [String] = []
        for line in lines {
            let blank = line.trimmed.isEmpty
            if blank && (result.isEmpty || result.last?.trimmed.isEmpty == true) { continue }
            result.append(blank ? "" : line)
        }
        while result.last?.trimmed.isEmpty == true { result.removeLast() }
        return result
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
