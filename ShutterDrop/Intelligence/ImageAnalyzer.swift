import CoreGraphics
import FoundationModels
import OSLog
import Vision

/// Looks at a photo: Vision names what's in it and reads any text on this
/// iPhone, and Apple Intelligence writes the alt text, on this iPhone or, when
/// the user allows it, on Private Cloud Compute.
nonisolated struct ImageAnalyzer {
    struct Labels: Sendable {
        /// Vision's most confident scene and object labels, best first.
        var scene: [String] = []
        /// Text in the photo, such as a sign.
        var text: [String] = []
    }

    /// What the models can draw on besides the photo itself.
    struct Context: Sendable {
        /// The place name so far, like "West Point Lighthouse, Seattle, WA".
        var place = ""
        /// "Seattle, WA"
        var city = ""
        /// Named places near where the photo was taken, nearest first.
        var nearby: [String] = []
        /// "golden hour, with the sun low in the west"
        var light = ""
        /// "March 1, 2025"
        var date = ""
        var labels = Labels()
    }

    /// What Private Cloud Compute writes for a new photo.
    @Generable
    struct Draft {
        @Guide(description: "The landmark, natural feature or venue the photo shows, exactly as written in the nearby places list when one matches, or a famous name you're certain of from the photo itself. Empty when unsure.")
        var landmark: String
        @Guide(description: "Two sentences of alt text for a screen reader, under 70 words.")
        var altText: String
        @Guide(description: "Five Instagram hashtags, lowercase, each starting with #.", .count(5))
        var hashtags: [String]
    }

    func labels(for image: CGImage) async -> Labels {
        var labels = Labels()
        if let observations = try? await ClassifyImageRequest().perform(on: image) {
            labels.scene = observations
                .filter { $0.confidence >= 0.3 }
                .prefix(8)
                .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
        }
        var textRequest = RecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        if let observations = try? await textRequest.perform(on: image) {
            labels.text = observations
                .compactMap { $0.topCandidates(1).first?.string.trimmed }
                .filter { $0.count > 2 }
                .prefix(5)
                .map(\.self)
        }
        Log.altText.debug("Vision: \(labels.scene.count, privacy: .public) labels, \(labels.text.count, privacy: .public) text lines")
        return labels
    }

    /// Alt text from the on-device model, or nil when it can't run or
    /// declines.
    func altText(for image: CGImage, context: Context) async -> String? {
        guard AppleIntelligence.current == .ready else {
            Log.altText.info("Skipped alt text: Apple Intelligence isn't ready")
            return nil
        }
        let session = LanguageModelSession(instructions: Self.altTextInstructions)
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let response = try await session.respond {
                Self.prompt(for: context, includeNearby: false)
                Attachment(image).label("photo")
            }
            let text = Self.paragraph(response.content)
            Log.altText.info("Wrote alt text on device in \((clock.now - start).logText, privacy: .public): \(text, privacy: .private)")
            return text.isEmpty ? nil : text
        } catch {
            Log.altText.error("Apple Intelligence didn't write alt text: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// The place, alt text and hashtag ideas from Private Cloud Compute, or
    /// nil when it isn't usable or the request fails.
    func draft(for image: CGImage, context: Context) async -> Draft? {
        guard CloudModel.isUsable else { return nil }
        let session = LanguageModelSession(model: CloudModel.model, instructions: Self.draftInstructions)
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let response = try await session.respond(generating: Draft.self) {
                Self.prompt(for: context, includeNearby: true)
                Attachment(image).label("photo")
            }
            var draft = response.content
            draft.altText = Self.paragraph(draft.altText)
            Log.altText.info("Private Cloud Compute wrote a draft in \((clock.now - start).logText, privacy: .public): landmark \(draft.landmark.isEmpty ? "none" : draft.landmark, privacy: .private)")
            return draft
        } catch let error as PrivateCloudComputeLanguageModel.Error {
            Log.altText.error("Private Cloud Compute didn't answer: \(error.localizedDescription, privacy: .public); using this iPhone instead")
            return nil
        } catch {
            // A missing entitlement shows up here as a generic model error.
            Log.altText.error("Private Cloud Compute failed (is the entitlement on this app?): \(error.localizedDescription, privacy: .public); using this iPhone instead")
            return nil
        }
    }

    /// Alt text as one paragraph: the models sometimes break lines between
    /// sentences, which Instagram's alt text field doesn't want.
    static func paragraph(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// How alt text should read, shared by both models.
    static let altTextStyle = """
        Alt text is for people using screen readers. Write two concrete, \
        vivid sentences. The first names the subject (with the place name \
        when one is given), the setting and the light. The second describes \
        the composition and the mood. Describe only what you can see and the \
        details given; never mention camera settings or technique, and never \
        invent a place name. Never start with "This image", "The photo" or \
        "A photo of". No hashtags, emoji or quotation marks.
        """

    static let altTextInstructions = "You write alt text for photographs posted on Instagram. " + altTextStyle

    static let draftInstructions = """
        You prepare Instagram posts for a photographer. Look at the photo and \
        the details given.

        Landmark: name the specific place the photo shows. Prefer an exact \
        name from the nearby places list when it matches what you see, \
        including landmarks listed without a category. Ignore restrooms, \
        parking, trails, shops and stops unless they're clearly the subject. \
        Leave it empty rather than guess.

        """ + altTextStyle + """


        Hashtags: five tags a photographer would choose: the landmark, the \
        place or region, the photography niche of the subject, and the light \
        or season. No generic tags like #photo, #photography or #instagood.
        """

    static func prompt(for context: Context, includeNearby: Bool) -> String {
        var lines = ["Here is the photo labeled \"photo\"."]
        if !context.place.isEmpty { lines.append("Place: \(context.place)") }
        if includeNearby, !context.city.isEmpty { lines.append("City: \(context.city)") }
        if !context.date.isEmpty { lines.append("Taken: \(context.date)") }
        if !context.light.isEmpty { lines.append("Light when taken: \(context.light)") }
        if !context.labels.scene.isEmpty { lines.append("Vision sees: \(context.labels.scene.joined(separator: ", "))") }
        if !context.labels.text.isEmpty { lines.append("Text in the photo: \(context.labels.text.joined(separator: " / "))") }
        if includeNearby, !context.nearby.isEmpty {
            lines.append("Nearby places, nearest first:\n" + context.nearby.map { "- \($0)" }.joined(separator: "\n"))
        }
        return lines.joined(separator: "\n")
    }
}
