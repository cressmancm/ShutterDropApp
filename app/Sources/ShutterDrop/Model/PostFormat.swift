import Foundation

/// How photo details read in a post. A reading the photo doesn't have comes
/// back empty, never as "0 mm" or "f/0", so its token drops out.
enum PostFormat {
    /// "125"
    static func iso(_ value: Double?) -> String {
        guard let value, value > 0 else { return "" }
        return String(Int(value.rounded()))
    }

    /// "340", rounded to the nearest millimeter.
    static func focalLength(_ millimeters: Double?) -> String {
        guard let millimeters, millimeters > 0 else { return "" }
        return String(Int(millimeters.rounded()))
    }

    /// "5.6", or "6" for a whole f-number.
    static func aperture(_ fNumber: Double?) -> String {
        guard let fNumber, fNumber > 0 else { return "" }
        return oneDecimal(fNumber)
    }

    /// "1/125" under a second, "2" or "1.5" from a second up.
    static func shutter(_ seconds: Double?) -> String {
        guard let seconds, seconds > 0 else { return "" }
        if seconds < 1 {
            return "1/\(Int((1 / seconds).rounded()))"
        }
        return oneDecimal(seconds)
    }

    /// "125 ISO | 340 mm | f/6 | 1/125 s", leaving out readings that are empty.
    static func exposure(iso: String, focalLength: String, aperture: String, shutter: String) -> String {
        [
            iso.isEmpty ? nil : "\(iso) ISO",
            focalLength.isEmpty ? nil : "\(focalLength) mm",
            aperture.isEmpty ? nil : "f/\(aperture)",
            shutter.isEmpty ? nil : "\(shutter) s",
        ]
        .compactMap(\.self)
        .joined(separator: " | ")
    }

    /// "NIKON Z 8 with NIKKOR Z 180-600mm f/5.6-6.3 VR", or just the model when
    /// the lens is built in or unknown (phones).
    static func cameraLine(model: String, lens: String) -> String {
        let model = model.trimmed
        let lens = lens.trimmed
        guard !model.isEmpty else { return lens }
        if lens.isEmpty || lens == model || lens.hasPrefix(model) { return model }
        return "\(model) with \(lens)"
    }

    /// "March 1, 2025"
    static func date(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    private static func oneDecimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%.1f", rounded)
    }
}
