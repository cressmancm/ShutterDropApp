import Foundation
import Testing
@testable import ShutterDrop

@Suite("Photo detail formatting")
struct PostFormatTests {
    @Test("Shutter speeds under a second read as fractions")
    func shutterFractions() {
        #expect(PostFormat.shutter(0.008) == "1/125")
        #expect(PostFormat.shutter(1.0 / 4000) == "1/4000")
        #expect(PostFormat.shutter(0.3) == "1/3")
    }

    @Test("Shutter speeds from a second up read in seconds")
    func shutterSeconds() {
        #expect(PostFormat.shutter(2) == "2")
        #expect(PostFormat.shutter(1.5) == "1.5")
    }

    @Test("Apertures keep one decimal and drop .0")
    func aperture() {
        #expect(PostFormat.aperture(5.6) == "5.6")
        #expect(PostFormat.aperture(6.0) == "6")
        #expect(PostFormat.aperture(1.78) == "1.8")
    }

    @Test("Focal length and ISO round to whole numbers")
    func wholeNumbers() {
        #expect(PostFormat.focalLength(339.6) == "340")
        #expect(PostFormat.iso(125) == "125")
    }

    @Test("Missing or zero readings come back empty")
    func missingReadings() {
        #expect(PostFormat.iso(nil) == "")
        #expect(PostFormat.focalLength(0) == "")
        #expect(PostFormat.aperture(0) == "")
        #expect(PostFormat.shutter(nil) == "")
    }

    @Test("Exposure joins only the readings that exist")
    func exposure() {
        #expect(PostFormat.exposure(iso: "125", focalLength: "340", aperture: "6", shutter: "1/125") == "125 ISO | 340 mm | f/6 | 1/125 s")
        #expect(PostFormat.exposure(iso: "125", focalLength: "", aperture: "1.8", shutter: "1/120") == "125 ISO | f/1.8 | 1/120 s")
        #expect(PostFormat.exposure(iso: "", focalLength: "", aperture: "", shutter: "") == "")
    }

    @Test("Camera line names the lens unless it's built in")
    func cameraLine() {
        #expect(PostFormat.cameraLine(model: "NIKON Z 8", lens: "NIKKOR Z 180-600mm f/5.6-6.3 VR") == "NIKON Z 8 with NIKKOR Z 180-600mm f/5.6-6.3 VR")
        #expect(PostFormat.cameraLine(model: "iPhone 17 Pro", lens: "iPhone 17 Pro back triple camera 6.765mm f/1.78") == "iPhone 17 Pro")
        #expect(PostFormat.cameraLine(model: "iPhone 17 Pro", lens: "") == "iPhone 17 Pro")
        #expect(PostFormat.cameraLine(model: "", lens: "") == "")
    }

    @Test("Dates read as Month Day, Year")
    func date() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = calendar.date(from: DateComponents(year: 2025, month: 3, day: 1, hour: 12))!
        #expect(PostFormat.date(date) == "March 1, 2025")
    }
}
