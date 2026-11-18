import CoreGraphics
import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers

/// Claude, with the user's own Anthropic API key. When turned on it sees each
/// new photo the way the original ShutterDrop skill did: it names the place
/// the photo shows, writes the alt text, and researches five hashtags on the
/// web. Anthropic bills the user's own account.
///
/// Off until the user saves a key and turns it on. Whenever it can't run (no
/// key, no connection, an error), ShutterDrop falls back to Apple's models.
nonisolated enum ClaudeModel {
    private static let keyAccount = "anthropic-api-key"

    static var apiKey: String? {
        Keychain.read(keyAccount)?.trimmed.nilIfEmpty
    }

    /// Whether a key is saved.
    static var isConfigured: Bool { apiKey != nil }

    /// Whether Anthropic turned the saved key away.
    static var keyRejected: Bool {
        UserDefaults.standard.bool(forKey: AppSettings.claudeKeyRejected)
    }

    /// Whether ShutterDrop uses Claude right now.
    static var isUsable: Bool {
        AppSettings.claudeEnabled && isConfigured && !keyRejected
    }

    static func saveKey(_ key: String) {
        Keychain.save(key.trimmed, for: keyAccount)
        UserDefaults.standard.set(false, forKey: AppSettings.claudeKeyRejected)
    }

    static func removeKey() {
        Keychain.delete(keyAccount)
        UserDefaults.standard.set(false, forKey: AppSettings.claudeKeyRejected)
        UserDefaults.standard.set(false, forKey: AppSettings.claudeAPI)
    }

    /// For Settings: why Claude can't run. Nil when it can.
    static var note: String? {
        if !isConfigured { return "Add your Anthropic API key to turn this on." }
        if keyRejected { return "Anthropic didn't accept this API key. Check it, and your credit, in the Claude Console, then save it again." }
        return nil
    }

    /// The place, alt text and hashtags from Claude, or nil when it isn't
    /// usable or the request fails.
    static func draft(for image: CGImage, context: ImageAnalyzer.Context, session: URLSession = .shared) async -> ImageAnalyzer.Draft? {
        guard isUsable, let apiKey, let jpeg = jpegData(image) else { return nil }
        let client = ClaudeClient(apiKey: apiKey, session: session)
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let prompt = ImageAnalyzer.prompt(for: context, includeNearby: true, includeCamera: true)
            let (draft, usage) = try await client.draft(imageJPEG: jpeg, prompt: prompt, instructions: instructions)
            Log.claude.info("Claude wrote a draft in \((clock.now - start).logText, privacy: .public): \(usage.inputTokens, privacy: .public) input and \(usage.outputTokens, privacy: .public) output tokens, \(usage.webSearches, privacy: .public) searches; landmark \(draft.landmark.isEmpty ? "none" : draft.landmark, privacy: .private)")
            return draft
        } catch ClaudeClient.Failure.keyRejected {
            Log.claude.error("Anthropic rejected the API key; using Apple's models until it's saved again")
            UserDefaults.standard.set(true, forKey: AppSettings.claudeKeyRejected)
            return nil
        } catch {
            Log.claude.error("Claude didn't answer: \(String(describing: error), privacy: .public); using Apple's models instead")
            return nil
        }
    }

    private static func jpegData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// The original skill's rules for the place, alt text and hashtags.
    static let instructions = """
        You prepare Instagram posts for a photographer. You get one photo and \
        the details ShutterDrop read from it. Study the photo carefully, \
        research hashtags on the web, then call \(ClaudeClient.submitTool) \
        once with the result.

        Place: name the most specific place the photo shows, without the \
        city or state, which ShutterDrop adds. In order of preference: a \
        landmark, venue or building you recognize in the photo; a place from \
        the nearby places list that matches what you see; the neighborhood or \
        district. Leave it empty when the city alone is the best answer. Never \
        use a street address or a highway name, and never guess.

        Alt text: two or three sentences for people using screen readers, as \
        one paragraph. Describe what the photo shows (subject, composition, \
        framing); where it was taken from and what it looks toward; the light \
        and mood; and any effect of the lens or exposure you can see, such as \
        telephoto compression or long-exposure blur. Never start with "This \
        image", "The photo" or "A photo of". No hashtags, emoji or quotation \
        marks.

        Hashtags: use web search to find Instagram hashtags for this kind of \
        photo, checking hashtag research sites such as best-hashtags.com for \
        approximate post counts when you can. Choose exactly 5, following this \
        tiered strategy:
        - 1-2 mid-range niche tags (10K-500K posts) for targeted reach
        - 1-2 specific or location tags for community connection
        - 0-1 broad tags (1M+ posts), only if highly relevant to the content
        - Avoid ultra-high-volume tags (10M+); they're too saturated to give real value
        - Avoid generic tags like #photography or #photo
        - Every tag must be specific to the scene, location or subject matter
        Write each tag lowercase, starting with #.
        """
}
