import Foundation
import SwiftData

/// Debug-build switches for testing and screenshots: launch arguments, and the
/// Debug Tools screen in Settings. Release builds compile none of it in, so
/// every switch reads as off there.
enum DebugOptions {
    /// True in Debug builds, where Settings shows Debug Tools.
    static var isEnabled: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// The settings key for a forced Apple Intelligence state. A launch
    /// argument (`-intelligenceState off`) and Debug Tools both set it.
    static let intelligenceStateKey = "intelligenceState"

    /// The Apple Intelligence states Debug Tools can force, by stored value.
    static let intelligenceStates: [(value: String, label: String)] = [
        ("", "Follow This Device"),
        ("ready", "Ready"),
        ("unsupported", "iPhone Not Supported"),
        ("off", "Turned Off"),
        ("downloading", "Downloading"),
    ]

    /// `-skipIntelligenceCheck`: show the app even where Apple Intelligence
    /// can't run, such as some simulators.
    static var skipIntelligenceCheck: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-skipIntelligenceCheck")
        #else
        false
        #endif
    }

    /// A forced Apple Intelligence state, or nil to follow the device.
    static var intelligenceState: AppleIntelligence? {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: intelligenceStateKey) {
        case "ready": .ready
        case "unsupported": .unsupportedDevice
        case "off": .turnedOff
        case "downloading": .downloading
        default: nil
        }
        #else
        nil
        #endif
    }

    /// `-sampleData`: fill an empty queue with example posts.
    static var sampleData: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-sampleData")
        #else
        false
        #endif
    }

    /// `-startTab posted|settings`: open on that tab.
    static var startTab: String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "startTab")
        #else
        nil
        #endif
    }

    /// `-openFirstPost`: open the newest post in the queue.
    static var openFirstPost: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-openFirstPost")
        #else
        false
        #endif
    }

    /// `-openDebugTools`: open Settings › Debug Tools (with `-startTab settings`).
    static var openDebugTools: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-openDebugTools")
        #else
        false
        #endif
    }

    /// With `-sampleData`, fills an empty store with example posts.
    @MainActor
    static func insertSampleData(into context: ModelContext) {
        guard sampleData, ((try? context.fetchCount(FetchDescriptor<Post>())) ?? 0) == 0 else { return }
        addSamplePosts(into: context)
    }

    /// Adds four example posts: three in the queue (one with no location) and
    /// one already posted. They have no photo, so their images are blank.
    @MainActor
    static func addSamplePosts(into context: ModelContext) {
        let calendar = Calendar(identifier: .gregorian)
        func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        }
        let examples: [(String, String, String, String, Date, Bool)] = [
            ("Zona Romántica, Puerto Vallarta, Jal.", "NIKON Z 8", "NIKKOR Z 180-600mm f/5.6-6.3 VR", "125 ISO | 340 mm | f/6 | 1/125 s", day(2025, 3, 1), false),
            ("Pike Place Market, Seattle, WA", "iPhone 17 Pro", "", "64 ISO | f/1.8 | 1/240 s", day(2025, 2, 14), false),
            ("", "NIKON Z 8", "NIKKOR Z 24-120mm f/4 S", "100 ISO | 24 mm | f/8 | 2 s", day(2025, 1, 30), false),
            ("Snoqualmie Falls, Snoqualmie, WA", "NIKON Z 8", "NIKKOR Z 24-120mm f/4 S", "64 ISO | 35 mm | f/11 | 1/4 s", day(2024, 11, 9), true),
        ]
        for (index, example) in examples.enumerated() {
            let post = Post(assetID: "sample-\(UUID().uuidString)", source: .imported, dateTaken: example.4)
            post.location = example.0
            post.cameraModel = example.1
            post.lensModel = example.2
            post.cameraLine = PostFormat.cameraLine(model: example.1, lens: example.2)
            post.exposure = example.3
            post.hashtags = index == 0 ? "#puertovallarta #zonaromantica" : ""
            post.altText = index == 0 ? "Rooftops of the old town step down toward the bay, shot from a hillside with a long lens that stacks the buildings close together. Late sun warms the walls and the water beyond." : ""
            post.processedAt = .now
            post.setPosted(example.5)
            context.insert(post)
        }
        try? context.save()
    }
}
