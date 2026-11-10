import Foundation

/// Settings keys, shared by `@AppStorage` in views and `UserDefaults` in services.
nonisolated enum AppSettings {
    static let postTemplate = "postTemplate"
    static let locationLookups = "locationLookups"
    static let onboardingDone = "onboardingDone"
    static let altTextGeneration = "altTextGeneration"
    static let privateCloudCompute = "privateCloudCompute"

    static var template: String {
        UserDefaults.standard.string(forKey: postTemplate) ?? PostTemplate.defaultText
    }

    /// Whether the user wants Apple Intelligence to write alt text. On
    /// unless they said no in onboarding or Settings.
    static var altTextEnabled: Bool {
        UserDefaults.standard.object(forKey: altTextGeneration) as? Bool ?? true
    }

    /// Whether ShutterDrop writes alt text right now: the user wants it and
    /// Apple Intelligence can run, on this iPhone or on Private Cloud Compute.
    static var writesAltText: Bool {
        altTextEnabled && (AppleIntelligence.current == .ready || CloudModel.isUsable)
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
