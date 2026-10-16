import Foundation

/// Hashtag helpers: cleaning pasted text, suggesting tags, and building the
/// search page address. The research itself happens on the search site.
enum Hashtags {
    /// The #tags in any text, in order, without repeats (ignoring case).
    static func extract(from text: String) -> [String] {
        var seen = Set<String>()
        var tags: [String] = []
        for match in text.matches(of: #/#[\p{L}\p{N}_]+/#) {
            let tag = String(match.output)
            if seen.insert(tag.lowercased()).inserted { tags.append(tag) }
        }
        return tags
    }

    /// Pasted text cut down to its #tags, single-spaced.
    static func clean(_ text: String) -> String {
        extract(from: text).joined(separator: " ")
    }

    /// `existing` with `tags` added on the end, skipping ones already there.
    static func adding(_ tags: [String], to existing: String) -> String {
        clean(existing + " " + tags.joined(separator: " "))
    }

    /// "Zona Romántica" → "#zonaromantica"
    static func tag(from phrase: String) -> String? {
        let slug = phrase
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        return slug.count >= 3 ? "#\(slug)" : nil
    }

    /// Tags to offer under the Hashtags field: from the place name, the
    /// camera, and the tags used most on other posts. No AI is involved.
    static func suggestions(location: String, camera: String, current: String, history: [String], limit: Int = 8) -> [String] {
        let have = Set(extract(from: current).map { $0.lowercased() })
        var candidates: [String] = []
        for part in location.components(separatedBy: ",") {
            let part = part.trimmed
            // Skip abbreviations like "Jal." or "CA".
            guard part.count > 3, !part.hasSuffix(".") else { continue }
            if let tag = tag(from: part) { candidates.append(tag) }
        }
        if let tag = tag(from: camera) { candidates.append(tag) }

        var counts: [String: Int] = [:]
        var spelling: [String: String] = [:]
        for tag in history.flatMap(extract(from:)) {
            counts[tag.lowercased(), default: 0] += 1
            spelling[tag.lowercased()] = spelling[tag.lowercased()] ?? tag
        }
        let popular = counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        candidates += popular.compactMap { spelling[$0.key] }

        var seen = have
        return candidates.filter { seen.insert($0.lowercased()).inserted }.prefix(limit).map(\.self)
    }

    /// What to search for first: the place, else what Vision saw.
    static func searchTerm(location: String, sceneLabels: [String]) -> String {
        if let first = location.components(separatedBy: ",").first?.trimmed, !first.isEmpty,
           let tag = tag(from: first) {
            return String(tag.dropFirst())
        }
        return sceneLabels.first.flatMap { tag(from: $0) }.map { String($0.dropFirst()) } ?? ""
    }

    /// The search page for `term`, from a site address with a {query} tag.
    static func searchURL(site: String, term: String) -> URL? {
        let term = term.trimmed.replacingOccurrences(of: "#", with: "")
        guard !term.isEmpty,
              let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?&=")))
        else { return nil }
        let address = site.contains("{query}") ? site.replacingOccurrences(of: "{query}", with: encoded) : site + encoded
        guard let url = URL(string: address), url.scheme == "https" || url.scheme == "http" else { return nil }
        return url
    }
}
