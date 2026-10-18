import CoreLocation
import MapKit

/// Turns a photo's GPS position into a place name for the post, like
/// "Pike Place Market, Seattle, WA" or "Amapas, Puerto Vallarta, Jal.", using
/// Apple's MapKit. Only the position is sent to Apple, and only when Location
/// Lookups is on.
enum LocationNamer {
    /// Places worth naming in a post when the photo was taken near one and
    /// nothing better is known.
    static let landmarkCategories: [MKPointOfInterestCategory] = [
        .landmark, .nationalMonument, .nationalPark, .park, .beach, .museum,
        .castle, .fortress, .scenicView, .stadium, .zoo, .aquarium,
        .amusementPark, .marina, .planetarium,
    ]

    /// How close a landmark has to be to the photo to be named, in meters.
    static let landmarkRadius: CLLocationDistance = 250

    struct Candidates: Equatable {
        /// The place MapKit names, like "Pike Place Market", when it's a
        /// place rather than the street address.
        var namedPlace: String?
        var neighborhood: String?
        var nearbyLandmark: String?
        /// "Puerto Vallarta, Jal." or "Seattle, WA"
        var city: String?
    }

    /// The place name for a GPS position. Photos from one spot share an
    /// answer, and requests to Apple are spaced out, so a big first run
    /// doesn't get throttled.
    static func placeName(latitude: Double, longitude: Double) async -> String? {
        await PlaceLookups.shared.placeName(latitude: latitude, longitude: longitude)
    }

    /// One lookup, without the cache. Each MapKit request waits its turn.
    fileprivate static func lookUp(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        let item: MKMapItem
        do {
            await PlaceLookups.shared.waitTurn()
            guard let first = try await mapItems(for: request).first else {
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
        if candidates.namedPlace == nil && candidates.neighborhood == nil {
            await PlaceLookups.shared.waitTurn()
            candidates.nearbyLandmark = await nearbyLandmark(around: location)
        }
        let name = compose(candidates)
        Log.location.info("Place name: \(name ?? "none", privacy: .private)")
        return name
    }

    /// The reverse geocoding results, retrying once after a pause if MapKit
    /// says ShutterDrop is asking too often.
    private static func mapItems(for request: MKReverseGeocodingRequest) async throws -> [MKMapItem] {
        do {
            return try await request.mapItems
        } catch let error as MKError where error.code == .loadingThrottled {
            Log.location.notice("MapKit is throttling lookups; waiting \(PlaceLookups.throttledPause.logText, privacy: .public) before one retry")
            try? await Task.sleep(for: PlaceLookups.throttledPause)
            return try await request.mapItems
        }
    }

    /// Picks the place to name: a named place, then the neighborhood, then a
    /// landmark near the photo, then the city alone. Street addresses and
    /// highways are never used.
    static func compose(_ candidates: Candidates) -> String? {
        let city = candidates.city?.trimmed.nilIfEmpty
        let place = [candidates.namedPlace, candidates.neighborhood, candidates.nearbyLandmark]
            .compactMap { $0?.trimmed.nilIfEmpty }
            .first

        guard let place else { return city }
        guard let city else { return place }
        if city.localizedCaseInsensitiveContains(place) { return city }
        return "\(place), \(city)"
    }

    /// MapKit names a spot after the place when there is one ("Pike Place
    /// Market", "Eiffel Tower") and after the street address otherwise
    /// ("Calle Falsa 123"). A name that's the start of the address is the
    /// address.
    static func namedPlace(name: String?, shortAddress: String?) -> String? {
        guard let name = name?.trimmed.nilIfEmpty,
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

    private static func nearbyLandmark(around location: CLLocation) async -> String? {
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: landmarkRadius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: landmarkCategories)
        guard let response = try? await MKLocalSearch(request: request).start() else { return nil }
        return response.mapItems
            .min { $0.location.distance(from: location) < $1.location.distance(from: location) }?
            .name
    }
}

extension String {
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

    private var answers: [String: String] = [:]
    private var nextSlot = ContinuousClock.now

    func placeName(latitude: Double, longitude: Double) async -> String? {
        let key = String(format: "%.3f,%.3f", latitude, longitude)
        if let known = answers[key] {
            Log.location.debug("Place name from an earlier photo nearby")
            return known
        }
        let name = await LocationNamer.lookUp(latitude: latitude, longitude: longitude)
        // Only real answers are kept, so a failed lookup is tried again later.
        if let name { answers[key] = name }
        return name
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
