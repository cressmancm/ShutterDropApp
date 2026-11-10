import Foundation

/// Hashtag helpers: cleaning pasted text, suggesting tags, and building the
/// search page address. The research itself happens on the search site.
nonisolated enum Hashtags {
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

    /// Photography niches for what Vision sees, the kind of tag people
    /// browse on Instagram.
    static let niches: [String: String] = [
        "lighthouse": "#lighthousephotography",
        "waterfall": "#waterfallphotography",
        "bridge": "#bridgephotography",
        "beach": "#beachphotography",
        "mountain": "#mountainphotography",
        "lake": "#lakephotography",
        "forest": "#forestphotography",
        "desert": "#desertphotography",
        "canyon": "#canyonphotography",
        "cityscape": "#cityscape",
        "skyscraper": "#architecturephotography",
        "night sky": "#nightphotography",
        "bird": "#birdphotography",
        "flower": "#flowerphotography",
        "boat": "#boatphotography",
        "sailboat": "#sailing",
        "castle": "#castlephotography",
    ]

    /// Regional photography communities, by state or province.
    static let regions: [String: String] = [
        "WA": "#pnwphotography", "OR": "#pnwphotography", "ID": "#pnwphotography", "BC": "#pnwphotography",
        "CA": "#californiaphotography", "HI": "#hawaiiphotography", "AK": "#alaskaphotography",
        "CO": "#coloradophotography", "UT": "#utahphotography", "AZ": "#arizonaphotography",
    ]

    /// Tags to offer under the Hashtags field, best first: Private Cloud
    /// Compute's ideas when there are any, then the place, the photography
    /// niche, the region, the light, the camera and the tags used most on
    /// other posts.
    static func suggestions(
        location: String,
        camera: String,
        sceneLabels: [String] = [],
        light: SunPosition.Light? = nil,
        ideas: [String] = [],
        current: String,
        history: [String],
        limit: Int = 8
    ) -> [String] {
        let have = Set(extract(from: current).map { $0.lowercased() })
        var candidates = ideas.flatMap(extract(from:))
        let parts = location.components(separatedBy: ",").map(\.trimmed)
        var places: [String] = []
        for part in parts {
            // Skip abbreviations like "Jal." or "CA".
            guard part.count > 3, !part.hasSuffix(".") else { continue }
            if let tag = tag(from: part) { places.append(tag) }
        }
        // The landmark first, then the niche, then the city.
        candidates += places.prefix(1)
        candidates += sceneLabels.compactMap { niches[$0.lowercased()] }.prefix(2)
        if let state = parts.last?.uppercased().replacingOccurrences(of: ".", with: ""), let region = regions[state] {
            candidates.append(region)
        }
        switch light {
        case .goldenHour: candidates.append("#goldenhour")
        case .blueHour: candidates.append("#bluehour")
        case .night: candidates.append("#nightphotography")
        default: break
        }
        candidates += places.dropFirst()
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

    /// The best-hashtags.com page for `term`, the site the old ShutterDrop
    /// skill used. It's fixed so the in-app browser opens only that site.
    static func searchURL(term: String) -> URL? {
        let term = term.trimmed.replacingOccurrences(of: "#", with: "")
        guard !term.isEmpty,
              let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?&=")))
        else { return nil }
        return URL(string: "https://best-hashtags.com/hashtag/\(encoded)/")
    }
}
