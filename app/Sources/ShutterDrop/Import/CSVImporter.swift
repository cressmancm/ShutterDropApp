import Foundation
import Photos
import SwiftData

/// Brings in the posts from the old ShutterDrop.numbers sheet, exported as
/// CSV. Each row is matched to its photo by filename and date taken; rows with
/// no match come in as text-only posts.
struct CSVImporter {
    struct Result: Equatable {
        var imported = 0
        var matched = 0
        var posted = 0
        var textOnly: [String] = []
        var duplicates: [String] = []

        var summary: String {
            var lines = ["Imported \(imported) posts, \(matched) matched to photos, \(posted) already posted."]
            if !textOnly.isEmpty {
                lines.append("\(textOnly.count) had no matching photo and came in as text only: \(textOnly.prefix(5).joined(separator: ", "))\(textOnly.count > 5 ? "…" : "").")
            }
            if !duplicates.isEmpty {
                lines.append("\(duplicates.count) filenames matched more than one photo; the first was used: \(duplicates.prefix(5).joined(separator: ", ")).")
            }
            return lines.joined(separator: "\n\n")
        }
    }

    /// One row of the old sheet, by its column headers.
    struct Row: Equatable {
        var filename = ""
        var caption = ""
        var location = ""
        var camera = ""
        var exposure = ""
        var dateTaken = ""
        var hashtags = ""
        var posted = false
        var altText = ""

        init(fields: [String: String]) {
            filename = fields["Filename", default: ""].trimmed
            caption = fields["Caption", default: ""].trimmed
            location = fields["Location", default: ""].trimmed
            camera = fields["Camera", default: ""].trimmed
            exposure = fields["Exposure", default: ""].trimmed
            dateTaken = fields["Date Taken", default: ""].trimmed
            hashtags = Hashtags.clean(fields["Hashtags", default: ""])
            posted = ["true", "yes", "1"].contains(fields["Posted", default: ""].trimmed.lowercased())
            altText = fields["Alt Text", default: ""].trimmed
        }

        var date: Date? { PostFormat.parseDate(dateTaken) }
    }

    enum ImportError: LocalizedError {
        case notShutterDropSheet

        var errorDescription: String? {
            "This file doesn't look like an export of ShutterDrop.numbers. It needs a Filename column."
        }
    }

    let library: PhotoLibrary

    @MainActor
    func importPosts(from text: String, into context: ModelContext) async throws -> Result {
        let rows = try Self.rows(from: text)
        var existing = Dictionary(((try? context.fetch(FetchDescriptor<Post>())) ?? []).map { ($0.assetID, $0) }, uniquingKeysWith: { first, _ in first })
        var result = Result()

        for row in rows where !row.filename.isEmpty || !row.caption.isEmpty {
            let match = library.canReadAlbum ? findAsset(for: row) : nil
            if match?.duplicate == true { result.duplicates.append(row.filename) }

            let post: Post
            if let asset = match?.asset, let found = existing[asset.localIdentifier] {
                post = found
            } else {
                let id = match?.asset.localIdentifier ?? "imported-\(UUID().uuidString)"
                post = Post(assetID: id, source: .imported, filename: row.filename, dateTaken: row.date ?? match?.asset.creationDate)
                post.processedAt = .now
                context.insert(post)
                existing[id] = post
            }
            Self.fill(post, from: row)

            result.imported += 1
            if match != nil { result.matched += 1 } else { result.textOnly.append(row.filename.isEmpty ? "untitled" : row.filename) }
            if row.posted { result.posted += 1 }
        }
        try context.save()
        return result
    }

    /// Copies the sheet's values onto a post; an empty cell leaves the post's
    /// own value alone.
    static func fill(_ post: Post, from row: Row) {
        if !row.caption.isEmpty { post.caption = row.caption }
        if !row.location.isEmpty { post.location = row.location }
        if !row.camera.isEmpty { post.cameraLine = row.camera }
        if !row.exposure.isEmpty { post.exposure = row.exposure }
        if !row.dateTaken.isEmpty { post.dateText = row.dateTaken }
        if let date = row.date, post.dateTaken == nil { post.dateTaken = date }
        if !row.hashtags.isEmpty { post.hashtags = row.hashtags }
        if !row.altText.isEmpty { post.altText = row.altText }
        if row.posted && !post.isPosted { post.setPosted(true) }
    }

    /// The photo with this filename taken on the row's date. Looking only at
    /// that day keeps the search quick in a large library.
    @MainActor
    private func findAsset(for row: Row) -> (asset: PHAsset, duplicate: Bool)? {
        guard !row.filename.isEmpty, let date = row.date else { return nil }
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date))!
        let end = calendar.date(byAdding: .day, value: 2, to: start)!
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate)
        let result = PHAsset.fetchAssets(with: options)
        var matches: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            if library.filename(of: asset).caseInsensitiveCompare(row.filename) == .orderedSame {
                matches.append(asset)
            }
        }
        guard let first = matches.first else { return nil }
        return (first, matches.count > 1)
    }

    // MARK: CSV

    static func rows(from text: String) throws -> [Row] {
        let table = parse(text)
        guard let header = table.first, header.contains("Filename") else { throw ImportError.notShutterDropSheet }
        return table.dropFirst().map { cells in
            var fields: [String: String] = [:]
            for (index, name) in header.enumerated() where index < cells.count {
                fields[name] = cells[index]
            }
            return Row(fields: fields)
        }
    }

    /// RFC 4180 CSV: quoted fields may hold commas, line breaks and "" for a
    /// quote, as Numbers writes the Full Post column.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var iterator = text.replacingOccurrences(of: "\r\n", with: "\n").makeIterator()
        var pending: Character?

        while let character = pending ?? iterator.next() {
            pending = nil
            if quoted {
                if character == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { field.append("\"") } else { quoted = false; pending = next }
                    } else {
                        quoted = false
                    }
                } else {
                    field.append(character)
                }
                continue
            }
            switch character {
            case "\"" where field.isEmpty:
                quoted = true
            case ",":
                row.append(field)
                field = ""
            case "\n":
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            default:
                field.append(character)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        // Strip a byte order mark from the first header.
        if let first = rows.first?.first, first.hasPrefix("\u{FEFF}") {
            rows[0][0] = String(first.dropFirst())
        }
        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }
}
