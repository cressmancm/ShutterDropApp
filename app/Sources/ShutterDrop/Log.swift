import OSLog

/// ShutterDrop's log, by area. In Xcode's console, filter on the subsystem
/// com.chipcressman.shutterdrop to hide the system's own messages.
///
/// Place names, filenames and alt text are logged as private: Xcode shows them
/// while debugging, and the device's log keeps them hidden. Counts and
/// timings are public.
enum Log {
    private static let subsystem = "com.chipcressman.shutterdrop"

    /// Album sync, the photo picker, Remove, and the processing queue.
    static let intake = Logger(subsystem: subsystem, category: "Intake")
    /// Reading each photo: image data, details, filenames.
    static let photos = Logger(subsystem: subsystem, category: "Photos")
    /// MapKit place names.
    static let location = Logger(subsystem: subsystem, category: "Location")
    /// Vision labels and Apple Intelligence alt text.
    static let altText = Logger(subsystem: subsystem, category: "AltText")
    /// Copying and Open in Instagram.
    static let sharing = Logger(subsystem: subsystem, category: "Sharing")
    /// CSV import.
    static let importer = Logger(subsystem: subsystem, category: "Import")
}

extension Duration {
    /// "1.24 s", for log lines.
    var logText: String {
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return String(format: "%.2f s", seconds)
    }
}
