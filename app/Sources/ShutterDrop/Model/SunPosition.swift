import Foundation

/// Where the sun was when a photo was taken, worked out from the time and the
/// GPS position, with no lookup. It tells golden hour from midday, which the
/// alt text and hashtags use.
struct SunPosition: Equatable {
    /// Degrees above the horizon; negative once the sun has set.
    var elevation: Double
    /// Compass bearing in degrees, clockwise from north.
    var azimuth: Double

    enum Light: String {
        case daylight = "daylight"
        case goldenHour = "golden hour"
        case blueHour = "blue hour"
        case night = "night"
    }

    /// Golden hour runs from 6° above the horizon to 4° below it, and blue
    /// hour on down to 6° below.
    var light: Light {
        switch elevation {
        case 6...: .daylight
        case -4..<6: .goldenHour
        case -6 ..< -4: .blueHour
        default: .night
        }
    }

    /// "west", "southwest" and so on.
    var direction: String {
        let names = ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"]
        let index = Int((azimuth / 45).rounded()) % names.count
        return names[(index + names.count) % names.count]
    }

    /// For the alt text: "golden hour, with the sun low in the west".
    var description: String {
        switch light {
        case .daylight: elevation < 25 ? "daylight, with the sun low in the \(direction)" : "daylight, with the sun high"
        case .goldenHour: elevation > 0 ? "golden hour, with the sun low in the \(direction)" : "golden hour, just after sunset or before sunrise, glowing in the \(direction)"
        case .blueHour: "blue hour, after sunset or before sunrise"
        case .night: "night"
        }
    }

    /// The sun's position, accurate to a fraction of a degree, which is plenty
    /// for telling the light apart. From the U.S. Naval Observatory's
    /// low-precision formulas.
    init(date: Date, latitude: Double, longitude: Double) {
        let days = date.timeIntervalSince1970 / 86_400 + 2_440_587.5 - 2_451_545.0
        let meanLongitude = (280.460 + 0.9856474 * days).degreesNormalized
        let meanAnomaly = (357.528 + 0.9856003 * days).degreesNormalized.radians
        let eclipticLongitude = (meanLongitude + 1.915 * sin(meanAnomaly) + 0.020 * sin(2 * meanAnomaly)).radians
        let obliquity = (23.439 - 0.0000004 * days).radians

        let rightAscension = atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude)).degrees
        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let siderealTime = (280.46061837 + 360.98564736629 * days + longitude).degreesNormalized
        let hourAngle = (siderealTime - rightAscension).radians
        let latitude = latitude.radians

        elevation = asin(sin(latitude) * sin(declination) + cos(latitude) * cos(declination) * cos(hourAngle)).degrees
        azimuth = atan2(-sin(hourAngle), tan(declination) * cos(latitude) - sin(latitude) * cos(hourAngle))
            .degrees.degreesNormalized
    }

    /// The sun for a post, when it has both a time and a place.
    init?(date: Date?, latitude: Double?, longitude: Double?) {
        guard let date, let latitude, let longitude else { return nil }
        self.init(date: date, latitude: latitude, longitude: longitude)
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
    var degreesNormalized: Double {
        let value = truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }
}
