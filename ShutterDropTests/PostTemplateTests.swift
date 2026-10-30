import Testing
@testable import ShutterDrop

@Suite("Post template")
struct PostTemplateTests {
    /// The Puerto Vallarta example from the old ShutterDrop skill.
    let full = PostTemplate.Values(
        caption: "Golden hour over the old town.",
        location: "Zona Romántica, Puerto Vallarta, Jal.",
        camera: "NIKON Z 8",
        lens: "NIKKOR Z 180-600mm f/5.6-6.3 VR",
        cameraWithLens: "NIKON Z 8 with NIKKOR Z 180-600mm f/5.6-6.3 VR",
        exposure: "125 ISO | 340 mm | f/6 | 1/125 s",
        iso: "125",
        focalLength: "340",
        aperture: "6",
        shutter: "1/125",
        date: "March 1, 2025",
        hashtags: "#puertovallarta #zonaromantica"
    )

    @Test("The default template lays out a full post like the old Numbers formula")
    func defaultTemplate() {
        #expect(PostTemplate.render(PostTemplate.defaultText, values: full) == """
            Golden hour over the old town.

            📍 Zona Romántica, Puerto Vallarta, Jal.
            📷 Shot on NIKON Z 8 with NIKKOR Z 180-600mm f/5.6-6.3 VR
            🎆 125 ISO | 340 mm | f/6 | 1/125 s
            📅 March 1, 2025
            🎨 Edited in Lightroom CC

            #puertovallarta #zonaromantica
            """)
    }

    @Test("With no caption, the post starts at the location line")
    func noCaption() {
        var values = full
        values.caption = "  "
        let post = PostTemplate.render(PostTemplate.defaultText, values: values)
        #expect(post.hasPrefix("📍 Zona Romántica"))
    }

    @Test("With no location, the 📍 line is left out")
    func noLocation() {
        var values = full
        values.location = ""
        let post = PostTemplate.render(PostTemplate.defaultText, values: values)
        #expect(!post.contains("📍"))
        #expect(post.contains("Golden hour over the old town.\n\n📷 Shot on"))
    }

    @Test("Fixed lines with no tags always stay")
    func fixedLinesStay() {
        let post = PostTemplate.render(PostTemplate.defaultText, values: .init())
        #expect(post == "🎨 Edited in Lightroom CC")
    }

    @Test("A line with one filled tag and one empty tag stays, the empty one blank")
    func partlyFilledLine() {
        var values = PostTemplate.Values()
        values.camera = "iPhone 17 Pro"
        #expect(PostTemplate.render("{camera} · {lens}", values: values) == "iPhone 17 Pro · ")
    }

    @Test("Unknown tags stay as typed")
    func unknownTags() {
        #expect(PostTemplate.render("{weather} today", values: full) == "{weather} today")
    }

    @Test("Blank lines collapse to one and never lead or trail")
    func blankLines() {
        let template = "\n\n{caption}\n\n\n\n{location}\n\n{hashtags}\n\n"
        var values = full
        values.location = ""
        #expect(PostTemplate.render(template, values: values) == "Golden hour over the old town.\n\n#puertovallarta #zonaromantica")
    }

    @Test("A multi-line caption keeps its line breaks")
    func multilineCaption() {
        var values = full
        values.caption = "First line\nSecond line"
        #expect(PostTemplate.render("{caption}", values: values) == "First line\nSecond line")
    }

    @Test("{camera_with_lens} isn't mistaken for {camera}")
    func similarTags() {
        #expect(PostTemplate.tags(in: "Shot on {camera_with_lens}") == [.cameraWithLens])
    }
}
