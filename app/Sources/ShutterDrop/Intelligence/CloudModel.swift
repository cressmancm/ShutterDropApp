import FoundationModels

/// Apple's larger model on Private Cloud Compute. With the user's OK it sees
/// each new photo, picks the place it shows from what MapKit finds nearby,
/// and writes the alt text and hashtag ideas. Apple uses the photo only for
/// the request and doesn't store it.
///
/// It needs the Private Cloud Compute entitlement, a connection and an
/// Apple Intelligence iPhone, and each person gets a daily limit. Whenever it
/// can't run, ShutterDrop falls back to MapKit's place name and the on-device
/// model's alt text.
enum CloudModel {
    static let model = PrivateCloudComputeLanguageModel()

    /// Whether this build carries the entitlement. Calling the model without
    /// it crashes the app instead of throwing, so nothing touches `model`
    /// unless this is true. Set up in Signing.xcconfig.
    static var isEntitled: Bool {
        #if PRIVATE_CLOUD_COMPUTE
        true
        #else
        false
        #endif
    }

    /// Whether this iPhone can reach it.
    static var isAvailable: Bool {
        isEntitled && model.availability == .available
    }

    /// Whether ShutterDrop uses it right now: the user turned it on, it's
    /// available, and today's limit isn't used up.
    static var isUsable: Bool {
        AppSettings.cloudEnabled && isAvailable && !model.quotaUsage.isLimitReached
    }

    /// The iCloud+ upgrade for more requests, when Apple suggests one.
    static var limitIncreaseSuggestion: PrivateCloudComputeLanguageModel.QuotaUsage.LimitIncreaseSuggestion? {
        isEntitled ? model.quotaUsage.limitIncreaseSuggestion : nil
    }

    /// For Settings: why it can't run, or how close today's limit is. Nil
    /// when there's nothing to say.
    static var note: String? {
        guard isEntitled else { return nil }
        switch model.availability {
        case .unavailable(.deviceNotEligible):
            return "Needs an iPhone that supports Apple Intelligence."
        case .unavailable:
            return "Private Cloud Compute isn't ready on this iPhone yet."
        case .available:
            break
        }
        let usage = model.quotaUsage
        if usage.isLimitReached {
            if let reset = usage.resetDate {
                return "You've used today's Private Cloud Compute limit. It resets \(reset.formatted(.relative(presentation: .named))); until then, ShutterDrop works on this iPhone."
            }
            return "You've used today's Private Cloud Compute limit. Until it resets, ShutterDrop works on this iPhone."
        }
        if case .belowLimit(let info) = usage.status, info.isApproachingLimit {
            return "You're close to today's Private Cloud Compute limit."
        }
        return nil
    }
}
