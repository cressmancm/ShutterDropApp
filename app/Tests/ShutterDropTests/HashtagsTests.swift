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

    @Test("The search term is the place, else Vision's top label")
    func searchTerm() {
        #expect(Hashtags.searchTerm(location: "Zona Romántica, Puerto Vallarta, Jal.", sceneLabels: ["beach"]) == "zonaromantica")
        #expect(Hashtags.searchTerm(location: "", sceneLabels: ["sunset sky", "water"]) == "sunsetsky")
        #expect(Hashtags.searchTerm(location: "", sceneLabels: []) == "")
    }

    @Test("The search page fills in {query}")
    func searchURL() {
        #expect(Hashtags.searchURL(site: AppSettings.defaultHashtagSearchSite, term: "#puertovallarta")?.absoluteString == "https://best-hashtags.com/hashtag/puertovallarta/")
        #expect(Hashtags.searchURL(site: "https://example.com/search?q={query}", term: "puerto vallarta")?.absoluteString == "https://example.com/search?q=puerto%20vallarta")
        #expect(Hashtags.searchURL(site: "javascript:{query}", term: "x") == nil)
        #expect(Hashtags.searchURL(site: AppSettings.defaultHashtagSearchSite, term: "  ") == nil)
    }
}

@Suite("Place names")
struct LocationNamerTests {
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
    }

    @Test("The neighborhood is the part of the short address before the city")
    func neighborhood() {
        #expect(LocationNamer.neighborhood(shortAddress: "Calle Falsa 123, Amapas, Puerto Vallarta", cityName: "Puerto Vallarta") == "Amapas")
        #expect(LocationNamer.neighborhood(shortAddress: "1902 Pike Pl, Seattle", cityName: "Seattle") == nil)
        #expect(LocationNamer.neighborhood(shortAddress: "Main St, 98065, Snoqualmie", cityName: "Snoqualmie") == nil)
        #expect(LocationNamer.neighborhood(shortAddress: "Calle 5, Centro, Oaxaca", cityName: "Puerto Vallarta") == nil)
    }
}

@Suite("CSV import")
struct CSVImporterTests {
    @Test("Quoted fields keep commas, line breaks and quotes")
    func parse() {
        let csv = "A,B,C\r\n1,\"two, too\",\"line one\nline \"\"two\"\"\"\r\n"
        #expect(CSVImporter.parse(csv) == [["A", "B", "C"], ["1", "two, too", "line one\nline \"two\""]])
    }

    @Test("Rows map from the old sheet's headers")
    func rows() throws {
        let csv = """
            Photo,Filename,Caption,Location,Camera,Exposure,Date Taken,Hashtags,Full Post,Posted,Alt Text,Publish Season,Why This Season
            ,DSC_0001.NEF,Golden hour,"Zona Romántica, Puerto Vallarta, Jal.",NIKON Z 8 with NIKKOR Z 180-600mm f/5.6-6.3 VR,125 ISO | 340 mm | f/6 | 1/125 s,"March 1, 2025",#puertovallarta #zonaromantica,"Golden hour

            📍 Zona Romántica",TRUE,Rooftops at sunset.,Spring 2026,Capture date
            """
        let rows = try CSVImporter.rows(from: csv)
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.filename == "DSC_0001.NEF")
        #expect(row.location == "Zona Romántica, Puerto Vallarta, Jal.")
        #expect(row.posted)
        #expect(row.hashtags == "#puertovallarta #zonaromantica")
        #expect(row.date == PostFormat.parseDate("March 1, 2025"))
    }

    @Test("A file without a Filename column is refused")
    func wrongFile() {
        #expect(throws: CSVImporter.ImportError.self) { try CSVImporter.rows(from: "Name,Price\nTea,4") }
    }
}
