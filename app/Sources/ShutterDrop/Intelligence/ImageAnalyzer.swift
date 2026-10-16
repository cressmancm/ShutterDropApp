import CoreGraphics
import FoundationModels
import Vision

/// Looks at a photo on this iPhone: Vision names what's in it and reads any
/// text, and Apple's on-device model writes the alt text. Nothing is uploaded.
struct ImageAnalyzer {
    struct Labels: Sendable {
        /// Vision's most confident scene and object labels, best first.
        var scene: [String] = []
        /// Text in the photo, such as a sign.
        var text: [String] = []
    }

    /// What the alt text can draw on besides the photo itself.
    struct Context: Sendable {
        var place = ""
        var camera = ""
        var focalLength = ""
        var shutter = ""
        var labels = Labels()
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
        return labels
    }

    /// Two or three sentences of alt text, or nil when the model can't run or
    /// declines.
    func altText(for image: CGImage, context: Context) async -> String? {
        guard AppleIntelligence.current == .ready else { return nil }
        let session = LanguageModelSession(instructions: Self.instructions)
        do {
            let response = try await session.respond {
                Self.prompt(for: context)
                Attachment(image).label("photo")
            }
            let text = response.content.trimmed
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    static let instructions = """
        You write alt text for photographs that will be posted on Instagram, \
        for people using screen readers. Write two or three plain sentences. \
        Describe the subject, the composition and where the photo was taken \
        from, then the light and mood. Mention a place only when one is given. \
        Mention technique only when it shows in the photo, like a long exposure \
        blurring water or a telephoto lens compressing distance. Never start \
        with "This image" or "A photo of". No hashtags, no emoji, no quotation \
        marks around the answer.
        """

    static func prompt(for context: Context) -> String {
        var lines = ["Write alt text for the photo labeled \"photo\"."]
        if !context.place.isEmpty { lines.append("Taken at: \(context.place)") }
        if !context.camera.isEmpty { lines.append("Camera: \(context.camera)") }
        if !context.focalLength.isEmpty { lines.append("Focal length: \(context.focalLength) mm") }
        if !context.shutter.isEmpty { lines.append("Shutter speed: \(context.shutter) s") }
        if !context.labels.scene.isEmpty { lines.append("Vision sees: \(context.labels.scene.joined(separator: ", "))") }
        if !context.labels.text.isEmpty { lines.append("Text in the photo: \(context.labels.text.joined(separator: " / "))") }
        return lines.joined(separator: "\n")
    }
}
