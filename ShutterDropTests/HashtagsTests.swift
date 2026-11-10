import Foundation
import Testing
@testable import ShutterDrop

@Suite("Hashtags")
struct HashtagsTests {
    @Test("Pasted text is cut down to its #tags, without repeats")
    func clean() {
        let pasted = """
            Top hashtags for puerto vallarta:
            #puertovallarta #PuertoVallarta #mexico
            #zonaromantica, #vallarta_life (1.2M posts)
            """
        #expect(Hashtags.clean(pasted) == "#puertovallarta #mexico #zonaromantica #vallarta_life")
    }

    @Test("Tags keep accented letters")
    func accents() {
        #expect(Hashtags.extract(from: "#méxico #café") == ["#méxico", "#café"])
    }

    @Test("Adding skips tags already there")
    func adding() {
        #expect(Hashtags.adding(["#mexico", "#puertovallarta"], to: "#puertovallarta") == "#puertovallarta #mexico")
    }

    @Test("Place names become tags without accents or spaces")
    func tagFromPhrase() {
        #expect(Hashtags.tag(from: "Zona Romántica") == "#zonaromantica")
        #expect(Hashtags.tag(from: "NIKON Z 8") == "#nikonz8")
        #expect(Hashtags.tag(from: "LA") == nil)
    }

    @Test("Suggestions come from the place, the camera and past posts, minus what's there")
    func suggestions() {
        let suggestions = Hashtags.suggestions(
            location: "Zona Romántica, Puerto Vallarta, Jal.",
            camera: "NIKON Z 8",
            current: "#zonaromantica",
            history: ["#birds #mexico", "#mexico #sunset", "#mexico"]
        )
        #expect(suggestions == ["#puertovallarta", "#nikonz8", "#mexico", "#birds", "#sunset"])
    }

    @Test("Then the landmark, the niche, the region and the light, before the city and camera")
    func richSuggestions() {
        let suggestions = Hashtags.suggestions(
            location: "West Point Lighthouse, Seattle, WA",
            camera: "NIKON Z 8",
            sceneLabels: ["outdoor", "lighthouse", "beach"],
            light: .goldenHour,
            current: "",
            history: []
        )
        #expect(suggestions == ["#westpointlighthouse", "#lighthousephotography", "#beachphotography", "#pnwphotography", "#goldenhour", "#seattle", "#nikonz8"])
    }

    @Test("Private Cloud Compute's ideas come first")
    func ideasFirst() {
        let suggestions = Hashtags.suggestions(location: "Seattle, WA", camera: "", ideas: ["#discoverypark", "#seattle"], current: "", history: [])
        #expect(suggestions == ["#discoverypark", "#seattle", "#pnwphotography"])
    }

    @Test("The search term is the place, else Vision's top label")
    func searchTerm() {
        #expect(Hashtags.searchTerm(location: "Zona Romántica, Puerto Vallarta, Jal.", sceneLabels: ["beach"]) == "zonaromantica")
        #expect(Hashtags.searchTerm(location: "", sceneLabels: ["sunset sky", "water"]) == "sunsetsky")
        #expect(Hashtags.searchTerm(location: "", sceneLabels: []) == "")
    }

    @Test("The search page is on best-hashtags.com")
    func searchURL() {
        #expect(Hashtags.searchURL(term: "#puertovallarta")?.absoluteString == "https://best-hashtags.com/hashtag/puertovallarta/")
        #expect(Hashtags.searchURL(term: "puerto vallarta")?.absoluteString == "https://best-hashtags.com/hashtag/puerto%20vallarta/")
        #expect(Hashtags.searchURL(term: "a/b?c")?.absoluteString == "https://best-hashtags.com/hashtag/a%2Fb%3Fc/")
        #expect(Hashtags.searchURL(term: "  ") == nil)
    }
}

@Suite("Place names")
struct LocationNamerTests {
    @Test("The place the photo shows comes before everything else")
    func subjectFirst() {
        let name = LocationNamer.compose(.init(subject: "West Point Lighthouse", namedPlace: "S Beach Trail Overlook", neighborhood: "Magnolia", city: "Seattle, WA"))
        #expect(name == "West Point Lighthouse, Seattle, WA")
    }

    @Test("What Vision sees finds the nearest place with a matching name")
    func subjectMatching() {
        let nearby: [(name: String, distance: Double)] = [
            ("Drinking Fountain", 226), ("West Point Lighthouse", 320), ("Alki Point Lighthouse", 9294), ("North Beach", 1288),
        ]
        #expect(LocationNamer.subject(matching: ["lighthouse"], in: nearby) == "West Point Lighthouse")
        #expect(LocationNamer.subject(matching: ["waterfall"], in: nearby) == nil)
        #expect(LocationNamer.subjectLabels(in: ["outdoor", "Lighthouse", "sky", "beach"]) == ["lighthouse"])
    }

    @Test("Up-close subjects only match nearby")
    func closeSubjects() {
        #expect(LocationNamer.subject(matching: ["statue"], in: [("Pioneer Statue", 300)]) == "Pioneer Statue")
        #expect(LocationNamer.subject(matching: ["statue"], in: [("Pioneer Statue", 900)]) == nil)
        #expect(LocationNamer.subject(matching: ["waterfall"], in: [("Snoqualmie Falls", 900)]) == "Snoqualmie Falls")
        #expect(LocationNamer.subject(matching: ["bridge"], in: [("Golden Gate Bridge Vista Point", 400), ("Golden Gate Bridge", 1500)]) == "Golden Gate Bridge")
    }

    @Test("A named place comes first")
    func namedPlace() {
        let name = LocationNamer.compose(.init(namedPlace: "Pike Place Market", neighborhood: "Belltown", nearbyLandmark: "Overlook Walk", city: "Seattle, WA"))
        #expect(name == "Pike Place Market, Seattle, WA")
    }

    @Test("Then the neighborhood, then a nearby landmark")
    func fallbacks() {
        #expect(LocationNamer.compose(.init(neighborhood: "Amapas", nearbyLandmark: "Los Arcos", city: "Puerto Vallarta, Jal.")) == "Amapas, Puerto Vallarta, Jal.")
        #expect(LocationNamer.compose(.init(nearbyLandmark: "Snoqualmie Falls", city: "Snoqualmie, WA")) == "Snoqualmie Falls, Snoqualmie, WA")
    }

    @Test("With nothing better, the city alone")
    func cityOnly() {
        #expect(LocationNamer.compose(.init(city: "Seattle, WA")) == "Seattle, WA")
        #expect(LocationNamer.compose(.init()) == nil)
    }

    @Test("A place that's just the city isn't repeated")
    func noRepeat() {
        #expect(LocationNamer.compose(.init(neighborhood: "Seattle", city: "Seattle, WA")) == "Seattle, WA")
    }

    @Test("A name that's the street address isn't a place")
    func streetNames() {
        #expect(LocationNamer.namedPlace(name: "Calle Falsa 123", shortAddress: "Calle Falsa 123, Amapas, Puerto Vallarta") == nil)
        #expect(LocationNamer.namedPlace(name: "SE 69th Pl", shortAddress: "SE 69th Pl, Snoqualmie") == nil)
        #expect(LocationNamer.namedPlace(name: "Pike Place Market", shortAddress: "1902 Pike Pl, Seattle") == "Pike Place Market")
        #expect(LocationNamer.namedPlace(name: "Eiffel Tower", shortAddress: nil) == nil)
        #expect(LocationNamer.namedPlace(name: "766", shortAddress: "Djúpivogur") == nil)
    }

    @Test("The neighborhood is the part of the short address before the city")
    func neighborhood() {
        #expect(LocationNamer.neighborhood(shortAddress: "Calle Falsa 123, Amapas, Puerto Vallarta", cityName: "Puerto Vallarta") == "Amapas")
        #expect(LocationNamer.neighborhood(shortAddress: "1902 Pike Pl, Seattle", cityName: "Seattle") == nil)
        #expect(LocationNamer.neighborhood(shortAddress: "Main St, 98065, Snoqualmie", cityName: "Snoqualmie") == nil)
        #expect(LocationNamer.neighborhood(shortAddress: "Calle 5, Centro, Oaxaca", cityName: "Puerto Vallarta") == nil)
    }
}

@Suite("Alt text")
struct AltTextTests {
    @Test("Line breaks and doubled spaces become single spaces")
    func paragraph() {
        #expect(ImageAnalyzer.paragraph("Waterfall at the edge.  \n\nMist rises. ") == "Waterfall at the edge. Mist rises.")
    }
}

@Suite("Sun position")
struct SunPositionTests {
    // Seattle, June 21, 2025.
    let latitude = 47.6062, longitude = -122.3321

    @Test("High at midday")
    func midday() throws {
        let noon = try #require(ISO8601DateFormatter().date(from: "2025-06-21T20:12:00Z"))
        let sun = SunPosition(date: noon, latitude: latitude, longitude: longitude)
        #expect(abs(sun.elevation - 65.8) < 1)
        #expect(sun.direction == "south")
        #expect(sun.light == .daylight)
    }

    @Test("Golden hour, low in the northwest, before sunset")
    func evening() throws {
        // Sunset that day was 9:11 PM PDT.
        let evening = try #require(ISO8601DateFormatter().date(from: "2025-06-22T03:45:00Z"))
        let sun = SunPosition(date: evening, latitude: latitude, longitude: longitude)
        #expect(sun.light == .goldenHour)
        #expect(sun.direction == "northwest")
        #expect(sun.description.hasPrefix("golden hour, with the sun low"))
    }

    @Test("Blue hour, then night")
    func afterSunset() throws {
        let formatter = ISO8601DateFormatter()
        let blue = try #require(formatter.date(from: "2025-06-22T04:40:00Z"))
        let night = try #require(formatter.date(from: "2025-06-22T07:00:00Z"))
        #expect(SunPosition(date: blue, latitude: latitude, longitude: longitude).light == .blueHour)
        #expect(SunPosition(date: night, latitude: latitude, longitude: longitude).light == .night)
    }

    @Test("Needs a time and a place")
    func missing() {
        #expect(SunPosition(date: nil, latitude: 1, longitude: 1) == nil)
        #expect(SunPosition(date: .now, latitude: nil, longitude: 1) == nil)
    }
}
