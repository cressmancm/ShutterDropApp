import FoundationModels

/// Whether Apple's on-device model can run. ShutterDrop needs it, with no
/// fallback, so anything but `.ready` shows one of the requirement screens.
enum AppleIntelligence: Equatable {
    case ready
    /// Older iPhones: Apple Intelligence needs iPhone 15 Pro or later.
    case unsupportedDevice
    /// Turned off in Settings › Apple Intelligence & Siri.
    case turnedOff
    /// Still downloading; ShutterDrop carries on when it's done.
    case downloading

    static var current: AppleIntelligence {
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
