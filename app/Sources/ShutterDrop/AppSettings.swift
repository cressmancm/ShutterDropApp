import Foundation

/// Settings keys, shared by `@AppStorage` in views and `UserDefaults` in services.
enum AppSettings {
    static let postTemplate = "postTemplate"
    static let locationLookups = "locationLookups"
    static let hashtagSearchSite = "hashtagSearchSite"
    static let onboardingDone = "onboardingDone"
    static let altTextGeneration = "altTextGeneration"

    /// best-hashtags.com, the site the old ShutterDrop skill used.
    static let defaultHashtagSearchSite = "https://best-hashtags.com/hashtag/{query}/"

    static var template: String {
        UserDefaults.standard.string(forKey: postTemplate) ?? PostTemplate.defaultText
    }

    /// Whether the user wants Apple Intelligence to write alt text. On
    /// unless they said no in onboarding or Settings.
    static var altTextEnabled: Bool {
        UserDefaults.standard.object(forKey: altTextGeneration) as? Bool ?? true
    }

    /// Whether ShutterDrop writes alt text right now: the user wants it and
    /// Apple Intelligence can run.
    static var writesAltText: Bool {
        altTextEnabled && AppleIntelligence.current == .ready
    }

    /// On unless the user turned it off in onboarding or Settings.
    static var lookupsEnabled: Bool {
        UserDefaults.standard.object(forKey: locationLookups) as? Bool ?? true
    }
}
