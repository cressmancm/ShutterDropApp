import Foundation
import UIKit

/// Copies of photos chosen with the photo picker. Without library access
/// ShutterDrop can't read them from Photos later, so it keeps its own copy
/// until the post is removed.
enum LocalImageStore {
    static func save(_ data: Data) throws -> String {
        let name = UUID().uuidString
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: url(for: name), options: .completeFileProtection)
        return name
    }

    static func data(named name: String) -> Data? {
        try? Data(contentsOf: url(for: name))
    }

    static func delete(named name: String) {
        try? FileManager.default.removeItem(at: url(for: name))
    }

    static func url(for name: String) -> URL {
        folder.appending(path: name)
    }

    private static var folder: URL {
        URL.applicationSupportDirectory.appending(path: "Picked Photos", directoryHint: .isDirectory)
    }
}
