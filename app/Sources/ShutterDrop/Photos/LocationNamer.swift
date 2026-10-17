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

    static func placeName(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first
        else { return nil }

        let shortAddress = item.address?.shortAddress
        var candidates = Candidates(
            namedPlace: namedPlace(name: item.name, shortAddress: shortAddress),
            neighborhood: neighborhood(shortAddress: shortAddress, cityName: item.addressRepresentations?.cityName),
            // The short style leaves out the country, as the old skill did.
            city: item.addressRepresentations?.cityWithContext(.short)
        )
        if candidates.namedPlace == nil && candidates.neighborhood == nil {
            candidates.nearbyLandmark = await nearbyLandmark(around: location)
        }
        return compose(candidates)
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
