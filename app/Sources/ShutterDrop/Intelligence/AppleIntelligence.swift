import FoundationModels
import SwiftUI

/// Whether Apple's on-device model can run. ShutterDrop uses it for one
/// thing, writing alt text, and it's optional: without it, people write
/// their own alt text and everything else works the same.
enum AppleIntelligence: Equatable {
    case ready
    /// Older iPhones: Apple Intelligence needs iPhone 15 Pro or later.
    case unsupportedDevice
    /// Turned off in Settings › Apple Intelligence & Siri.
    case turnedOff
    /// Still downloading; alt text starts when it's done.
    case downloading

    /// The state ShutterDrop acts on: the device's, unless Debug Tools or a
    /// launch argument forces one in a Debug build.
    static var current: AppleIntelligence {
        DebugOptions.intelligenceState ?? device
    }

    /// What this device actually reports.
    static var device: AppleIntelligence {
        switch SystemLanguageModel.default.availability {
        case .available:
            .ready
        case .unavailable(.deviceNotEligible):
            .unsupportedDevice
        case .unavailable(.appleIntelligenceNotEnabled):
            .turnedOff
        case .unavailable(.modelNotReady):
            .downloading
        case .unavailable:
            .downloading
        }
    }
}

extension AppleIntelligence {
    /// Whether this iPhone could ever write alt text; false only on iPhones
    /// that don't support Apple Intelligence.
    var isSupported: Bool { self != .unsupportedDevice }

    /// What the alt text setting can do right now, for Settings and the post
    /// screen. Nil when there's nothing to say.
    func altTextNote(enabled: Bool) -> String? {
        switch self {
        case .unsupportedDevice:
            "This iPhone doesn't support Apple Intelligence. You can still write alt text yourself."
        case .turnedOff where enabled:
            "Apple Intelligence is turned off on this iPhone. Turn it on in Settings › Apple Intelligence & Siri, and ShutterDrop starts writing alt text."
        case .downloading where enabled:
            "Your iPhone is still downloading Apple Intelligence. ShutterDrop starts writing alt text once that's done."
        case .ready where enabled:
            "Apple Intelligence writes alt text on this iPhone. Nothing is uploaded."
        default:
            nil
        }
    }
}

extension EnvironmentValues {
    /// The Apple Intelligence state, kept current by `RootView`.
    @Entry var appleIntelligence: AppleIntelligence = .ready
}
