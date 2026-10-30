import CoreLocation
import MapKit
import OSLog

/// Turns a photo's GPS position into a place name for the post, like
/// "West Point Lighthouse, Seattle, WA" or "Amapas, Puerto Vallarta, Jal.", using
/// Apple's MapKit. Only the position is sent to Apple, and only when Location
/// Lookups is on.
nonisolated enum LocationNamer {
    /// Places worth naming in a post when the photo was taken near one and
    /// nothing better is known.
    static let landmarkCategories: [MKPointOfInterestCategory] = [
        .landmark, .nationalMonument, .nationalPark, .park, .beach, .museum,
        .castle, .fortress, .scenicView, .stadium, .zoo, .aquarium,
        .amusementPark, .marina, .planetarium,
    ]

    /// How close a categorized landmark has to be to the photo to be named
    /// without anything else pointing to it, in meters.
    static let landmarkRadius: CLLocationDistance = 250
    /// How far to look for places matching what Vision saw, in meters. A
    /// telephoto shot of a lighthouse can be taken from well down the beach.
    static let subjectRadius: CLLocationDistance = 2000
    /// How far to look for places to offer Private Cloud Compute, in meters.
    static let nearbyRadius: CLLocationDistance = 1000

    /// What Vision sees that's usually a named place, and the words such a
    /// place's name contains. Many landmarks have no MapKit category (West
    /// Point Lighthouse doesn't), so matching names to the photo finds them.
    static let subjects: [String: [String]] = [
        "lighthouse": ["lighthouse", "light station"],
        "waterfall": ["falls", "waterfall", "cascade"],
        "bridge": ["bridge"],
        "castle": ["castle", "fort", "palace"],
        "belltower": ["tower", "campanile"],
        "clock tower": ["tower", "clock"],
        "tower": ["tower"],
        "ferris wheel": ["wheel"],
        "pier": ["pier", "wharf"],
        "fountain": ["fountain"],
        "monument": ["monument", "memorial"],
        "statue": ["statue", "monument", "memorial"],
        "stadium": ["stadium", "field", "arena", "ballpark"],
        "canyon": ["canyon", "gorge"],
        "glacier": ["glacier"],
        "arch": ["arch"],
    ]

    /// Subjects people photograph from up close, matched only within this
    /// many meters and never searched for farther out. Beaches and lakes
    /// aren't subjects at all: Vision sees them on any shoreline.
    static let closeSubjects: Set<String> = ["pier", "fountain", "monument", "statue", "arch"]
    static let closeRadius: CLLocationDistance = 500

    struct Candidates: Equatable {
        /// A nearby place whose name matches what Vision saw in the photo,
        /// like "West Point Lighthouse" for a photo labeled lighthouse.
        var subject: String?
        /// The place MapKit names, like "Pike Place Market", when it's a
        /// place rather than the street address.
        var namedPlace: String?
        var neighborhood: String?
        var nearbyLandmark: String?
        /// "Puerto Vallarta, Jal." or "Seattle, WA"
        var city: String?
    }

    /// A named place near the photo, for Private Cloud Compute to choose from.
    struct NearbyPlace: Sendable, Equatable {
        var name: String
        /// Meters from where the photo was taken.
        var distance: Int
        /// MapKit's category, like "Beach", when it has one.
        var category: String?

        /// "West Point Lighthouse (320 m)" or "Golden Gardens Park (900 m, Park)"
        var line: String {
            "\(name) (\(distance) m\(category.map { ", \($0)" } ?? ""))"
        }
    }

    /// Everything MapKit says about where a photo was taken.
    struct Place: Sendable, Equatable {
        /// The name ShutterDrop picks without Apple Intelligence.
        var name: String?
        var city: String?
        var nearby: [NearbyPlace] = []
    }

    /// The place for a GPS position. `sceneLabels` are Vision's labels for
    /// the photo, used to find the place it shows. Photos from one spot share
    /// an answer, and requests to Apple are spaced out, so a big first run
    /// doesn't get throttled.
    static func place(latitude: Double, longitude: Double, sceneLabels: [String] = []) async -> Place? {
        await PlaceLookups.shared.place(latitude: latitude, longitude: longitude, sceneLabels: sceneLabels)
    }

    /// The Vision labels that point to a named place, best first.
    static func subjectLabels(in sceneLabels: [String]) -> [String] {
        sceneLabels.map { $0.lowercased() }.filter { subjects[$0] != nil }
    }

    /// One lookup, without the cache. Each MapKit request waits its turn.
    fileprivate static func lookUp(latitude: Double, longitude: Double, subjectLabels: [String]) async -> Place? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        let item: MKMapItem
        do {
            guard let first = try await throttled({ try await request.mapItems }).first else {
                Log.location.info("MapKit found no place here")
                return nil
            }
            item = first
        } catch {
            Log.location.error("Reverse geocoding failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        let shortAddress = item.address?.shortAddress
        var candidates = Candidates(
            namedPlace: namedPlace(name: item.name, shortAddress: shortAddress),
            neighborhood: neighborhood(shortAddress: shortAddress, cityName: item.addressRepresentations?.cityName),
            // The short style leaves out the country, as the old skill did.
            city: item.addressRepresentations?.cityWithContext(.short)
        )

        let pointsOfInterest = await pointsOfInterest(around: location).filter(isLandmarkLike)
        candidates.subject = subject(matching: subjectLabels, in: pointsOfInterest, from: location)
        if candidates.subject == nil, let label = subjectLabels.first(where: { !closeSubjects.contains($0) }) {
            candidates.subject = await search(for: label, around: location)
        }
        candidates.nearbyLandmark = pointsOfInterest
            .filter { item in
                item.location.distance(from: location) <= landmarkRadius
                    && item.pointOfInterestCategory.map(landmarkCategories.contains) == true
            }
            .min { $0.location.distance(from: location) < $1.location.distance(from: location) }?
            .name

        let place = Place(
            name: compose(candidates),
            city: candidates.city,
            nearby: nearbyPlaces(pointsOfInterest, from: location)
        )
        Log.location.info("Place name: \(place.name ?? "none", privacy: .private)\(candidates.subject == nil ? "" : " (matched what Vision saw)", privacy: .public), \(place.nearby.count, privacy: .public) places nearby")
        return place
    }

    /// Runs a MapKit request in its turn, retrying once after a pause if
    /// MapKit says ShutterDrop is asking too often.
    private static func throttled<T>(_ request: () async throws -> T) async throws -> T {
        await PlaceLookups.shared.waitTurn()
        do {
            return try await request()
        } catch let error as MKError where error.code == .loadingThrottled {
            Log.location.notice("MapKit is throttling lookups; waiting \(PlaceLookups.throttledPause.logText, privacy: .public) before one retry")
            try? await Task.sleep(for: PlaceLookups.throttledPause)
            return try await request()
        }
    }

    /// Picks the place to name: the place the photo shows, then a named place,
    /// the neighborhood, a landmark near the photo, then the city alone.
    /// Street addresses and highways are never used.
    static func compose(_ candidates: Candidates) -> String? {
        let place = [candidates.subject, candidates.namedPlace, candidates.neighborhood, candidates.nearbyLandmark]
            .compactMap { $0?.trimmed.nilIfEmpty }
            .first
        return compose(place: place, city: candidates.city)
    }

    /// "West Point Lighthouse, Seattle, WA", without repeating the city.
    static func compose(place: String?, city: String?) -> String? {
        let city = city?.trimmed.nilIfEmpty
        guard let place = place?.trimmed.nilIfEmpty else { return city }
        guard let city else { return place }
        if city.localizedCaseInsensitiveContains(place) { return city }
        return "\(place), \(city)"
    }

    /// MapKit names a spot after the place when there is one ("Pike Place
    /// Market", "Eiffel Tower") and after the street address otherwise
    /// ("Calle Falsa 123"), or the postal code in the countryside ("766"). A
    /// name that's the start of the address, or has no letters, isn't a place.
    static func namedPlace(name: String?, shortAddress: String?) -> String? {
        guard let name = name?.trimmed.nilIfEmpty, name.contains(where: \.isLetter),
              let street = shortAddress?.components(separatedBy: ",").first?.trimmed
        else { return nil }
        return street.localizedCaseInsensitiveCompare(name) == .orderedSame ? nil : name
    }

    /// The neighborhood from a short address like "Calle Falsa 123, Amapas,
    /// Puerto Vallarta": the part just before the city, when there is one.
    static func neighborhood(shortAddress: String?, cityName: String?) -> String? {
        guard let parts = shortAddress?.components(separatedBy: ",").map(\.trimmed),
              parts.count >= 3,
              let cityName, parts.last?.localizedCaseInsensitiveCompare(cityName) == .orderedSame
        else { return nil }
        let candidate = parts[parts.count - 2]
        // Postal codes and street numbers aren't neighborhoods.
        guard !candidate.isEmpty, !candidate.contains(where: \.isNumber) else { return nil }
        return candidate
    }

    /// The nearest name containing a word for one of the labels, trying the
    /// labels in order. Names that end in the word, which name the thing
    /// itself, come before ones that only mention it.
    static func subject(matching labels: [String], in names: [(name: String, distance: Double)]) -> String? {
        for label in labels {
            guard let words = subjects[label] else { continue }
            let reach = closeSubjects.contains(label) ? closeRadius : subjectRadius
            let match = names
                .filter { item in item.distance <= reach && words.contains { item.name.localizedCaseInsensitiveContains($0) } }
                // "Golden Gate Bridge" over "Golden Gate Bridge Vista Point".
                .min { a, b in
                    let aEnds = words.contains { a.name.lowercased().hasSuffix($0) }
                    let bEnds = words.contains { b.name.lowercased().hasSuffix($0) }
                    return aEnds == bEnds ? a.distance < b.distance : aEnds
                }
            if let match { return match.name }
        }
        return nil
    }

    private static func subject(matching labels: [String], in items: [MKMapItem], from location: CLLocation) -> String? {
        subject(matching: labels, in: items.compactMap { item in
            item.name.map { ($0, item.location.distance(from: location)) }
        })
    }

    /// Landmark categories and uncategorized places, which include many
    /// landmarks, but not restaurants, hotels or shops, so a "beach" label
    /// doesn't match a beach club.
    static func isLandmarkLike(_ item: MKMapItem) -> Bool {
        item.pointOfInterestCategory.map(landmarkCategories.contains) ?? true
    }

    /// The points of interest near the photo. MapKit returns only the nearest
    /// few dozen, which downtown are all shops, so landmarks get a request
    /// of their own.
    private static func pointsOfInterest(around location: CLLocation) async -> [MKMapItem] {
        let landmarks = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: nearbyRadius)
        landmarks.pointOfInterestFilter = MKPointOfInterestFilter(including: landmarkCategories)
        let everything = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: nearbyRadius)
        var items: [MKMapItem] = []
        for request in [landmarks, everything] {
            do {
                items += try await throttled { try await MKLocalSearch(request: request).start().mapItems }
            } catch {
                // MapKit answers "not found" when there's nothing nearby.
                Log.location.debug("No points of interest nearby: \(error.localizedDescription, privacy: .public)")
            }
        }
        var seen = Set<String>()
        return items.filter { item in
            seen.insert("\(item.name ?? "")|\(Int(item.location.coordinate.latitude * 10_000))|\(Int(item.location.coordinate.longitude * 10_000))").inserted
        }
    }

    /// Searches near the photo for what Vision saw, like "lighthouse", and
    /// returns the nearest result whose name says it's one.
    private static func search(for label: String, around location: CLLocation) async -> String? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = label
        request.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: subjectRadius * 2, longitudinalMeters: subjectRadius * 2)
        request.regionPriority = .required
        request.resultTypes = .pointOfInterest
        guard let items = try? await throttled({ try await MKLocalSearch(request: request).start().mapItems }) else { return nil }
        return subject(matching: [label], in: items.filter { isLandmarkLike($0) && $0.location.distance(from: location) <= subjectRadius }, from: location)
    }

    /// Places worth offering Private Cloud Compute: landmark categories and
    /// uncategorized places, which include many landmarks, but not shops,
    /// restrooms or bus stops.
    private static func nearbyPlaces(_ items: [MKMapItem], from location: CLLocation) -> [NearbyPlace] {
        items
            .compactMap { item in
                item.name.map {
                    NearbyPlace(
                        name: $0,
                        distance: Int(item.location.distance(from: location)),
                        category: item.pointOfInterestCategory?.rawValue.replacingOccurrences(of: "MKPOICategory", with: "")
                    )
                }
            }
            // Categorized landmarks first, so shops without a category don't
            // crowd them out.
            .sorted { ($0.category == nil ? 1 : 0, $0.distance) < ($1.category == nil ? 1 : 0, $1.distance) }
            .prefix(20)
            .map(\.self)
    }
}

nonisolated extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// Spaces out MapKit requests and remembers answers for this run.
///
/// A first run over a big album can mean hundreds of lookups, and Apple
/// throttles apps that send them in a burst. Photos from the same shoot sit
/// within a few meters, so answers are kept by position, rounded to about
/// 100 m.
actor PlaceLookups {
    static let shared = PlaceLookups()

    /// The gap between MapKit requests.
    static let spacing: Duration = .milliseconds(1200)
    /// How long to wait after MapKit says to slow down.
    static let throttledPause: Duration = .seconds(10)

    private var answers: [String: LocationNamer.Place] = [:]
    private var nextSlot = ContinuousClock.now

    func place(latitude: Double, longitude: Double, sceneLabels: [String]) async -> LocationNamer.Place? {
        let subjectLabels = LocationNamer.subjectLabels(in: sceneLabels)
        // Photos from one spot of the same kind of subject share an answer.
        let key = String(format: "%.3f,%.3f", latitude, longitude) + "|" + (subjectLabels.first ?? "")
        if let known = answers[key] {
            Log.location.debug("Place from an earlier photo nearby")
            return known
        }
        let place = await LocationNamer.lookUp(latitude: latitude, longitude: longitude, subjectLabels: subjectLabels)
        // Only real answers are kept, so a failed lookup is tried again later.
        if let place { answers[key] = place }
        return place
    }

    /// Waits until it's this request's turn. The slot is claimed before
    /// sleeping, so requests that arrive together still go out spaced apart.
    func waitTurn() async {
        let now = ContinuousClock.now
        let slot = max(now, nextSlot)
        nextSlot = slot + Self.spacing
        if slot > now { try? await Task.sleep(until: slot, clock: .continuous) }
    }
}
