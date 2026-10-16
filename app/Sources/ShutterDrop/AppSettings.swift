import Foundation

/// Settings keys, shared by `@AppStorage` in views and `UserDefaults` in services.
enum AppSettings {
    static let postTemplate = "postTemplate"
    static let locationLookups = "locationLookups"
    static let hashtagSearchSite = "hashtagSearchSite"
    static let onboardingDone = "onboardingDone"

    /// best-hashtags.com, the site the old ShutterDrop skill used.
    static let defaultHashtagSearchSite = "https://best-hashtags.com/hashtag/{query}/"

    static var template: String {
        UserDefaults.standard.string(forKey: postTemplate) ?? PostTemplate.defaultText
    }

    /// On unless the user turned it off in onboarding or Settings.
    static var lookupsEnabled: Bool {
        UserDefaults.standard.object(forKey: locationLookups) as? Bool ?? true
    }
}
