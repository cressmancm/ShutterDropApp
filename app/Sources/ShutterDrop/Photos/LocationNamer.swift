import CoreLocation
import MapKit

/// Turns a photo's GPS position into a place name for the post, like
/// "Zona Romántica, Puerto Vallarta, Jal.", using Apple's MapKit. Only the
/// position is sent to Apple, and only when Location Lookups is on.
enum LocationNamer {
    /// Places worth naming in a post when the photo was taken near one.
    static let landmarkCategories: [MKPointOfInterestCategory] = [
        .landmark, .nationalMonument, .nationalPark, .park, .beach, .museum,
        .castle, .fortress, .scenicView, .stadium, .zoo, .aquarium,
        .amusementPark, .marina, .university, .planetarium,
    ]

    /// How close a landmark has to be to the photo to be named, in meters.
    static let landmarkRadius: CLLocationDistance = 250

    struct Candidates: Equatable {
        var areasOfInterest: [String] = []
        var nearbyLandmark: String?
        var neighborhood: String?
        /// "Puerto Vallarta, Jal."
        var cityWithContext: String?
    }

    static func placeName(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first
        else { return nil }

        var candidates = Candidates()
        candidates.cityWithContext = item.addressRepresentations?.cityWithContext
        // MapKit's newer address types don't carry neighborhoods or areas of
        // interest yet, so those still come from the placemark.
        let placemark = item.placemark
        candidates.areasOfInterest = placemark.areasOfInterest ?? []
        candidates.neighborhood = placemark.subLocality
        if candidates.cityWithContext == nil, let city = placemark.locality {
            candidates.cityWithContext = [city, placemark.administrativeArea].compactMap(\.self).joined(separator: ", ")
        }
        candidates.nearbyLandmark = await nearbyLandmark(around: location)
        return compose(candidates)
    }

    /// Picks the place to name: an area of interest, then a landmark near the
    /// photo, then the neighborhood, then the city alone. Street addresses and
    /// highways are never used.
    static func compose(_ candidates: Candidates) -> String? {
        let city = candidates.cityWithContext?.trimmed.nilIfEmpty
        let place = (candidates.areasOfInterest.map(\.trimmed) + [candidates.nearbyLandmark?.trimmed, candidates.neighborhood?.trimmed].compactMap(\.self))
            .first { !$0.isEmpty }

        guard let place else { return city }
        guard let city else { return place }
        if city.localizedCaseInsensitiveContains(place) { return city }
        return "\(place), \(city)"
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
