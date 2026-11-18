import Foundation

/// Settings keys, shared by `@AppStorage` in views and `UserDefaults` in services.
nonisolated enum AppSettings {
    static let postTemplate = "postTemplate"
    static let locationLookups = "locationLookups"
    static let onboardingDone = "onboardingDone"
    static let altTextGeneration = "altTextGeneration"
    static let privateCloudCompute = "privateCloudCompute"
    static let claudeAPI = "claudeAPI"
    /// Set when Anthropic turns the saved key away, cleared when a key is saved.
    static let claudeKeyRejected = "claudeKeyRejected"

    static var template: String {
        UserDefaults.standard.string(forKey: postTemplate) ?? PostTemplate.defaultText
    }

    /// Whether the user wants Apple Intelligence to write alt text. On
    /// unless they said no in onboarding or Settings.
    static var altTextEnabled: Bool {
        UserDefaults.standard.object(forKey: altTextGeneration) as? Bool ?? true
    }

    /// Whether ShutterDrop writes alt text right now: the user wants it and a
    /// model can run: Claude, Private Cloud Compute or this iPhone.
    static var writesAltText: Bool {
        altTextEnabled && (AppleIntelligence.current == .ready || CloudModel.isUsable || ClaudeModel.isUsable)
    }

    /// Whether the user lets ShutterDrop send photos to Claude with their own
    /// API key. Off until they turn it on.
    static var claudeEnabled: Bool {
        UserDefaults.standard.bool(forKey: claudeAPI)
    }

    /// Whether the user lets ShutterDrop send photos to Private Cloud Compute.
    /// Off until they turn it on, and always off in builds without the
    /// entitlement.
    static var cloudEnabled: Bool {
        CloudModel.isEntitled && UserDefaults.standard.bool(forKey: privateCloudCompute)
    }

    /// On unless the user turned it off in onboarding or Settings.
    static var lookupsEnabled: Bool {
        UserDefaults.standard.object(forKey: locationLookups) as? Bool ?? true
    }
}
