import Foundation
import Testing
@testable import ShutterDrop

/// Answers ShutterDrop's requests to Anthropic with canned responses, and
/// keeps each request for the test to check.
final class StubAnthropic: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [(status: Int, body: JSONValue)] = []
    nonisolated(unsafe) static var requests: [(request: URLRequest, body: JSONValue)] = []

    static func session(_ responses: [(status: Int, body: JSONValue)]) -> URLSession {
        self.responses = responses
        requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubAnthropic.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 65_536)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            stream.close()
        }
        Self.requests.append((request, (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .null))
        let (status, body) = Self.responses.isEmpty ? (500, JSONValue.null) : Self.responses.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: (try? JSONEncoder().encode(body)) ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("Claude client", .serialized)
struct ClaudeClientTests {
    let image = Data([0xFF, 0xD8, 0xFF])

    func client(_ responses: [(status: Int, body: JSONValue)]) -> ClaudeClient {
        ClaudeClient(apiKey: "test-key", session: StubAnthropic.session(responses), retryDelay: .zero)
    }

    static func submitted(_ hashtags: [JSONValue] = ["#westpointlighthouse", "#discoverypark", "#seattle", "#pnwlighthouses", "#goldenhour"]) -> JSONValue {
        [
            "content": [
                ["type": "text", "text": "Here's what I found."],
                ["type": "tool_use", "id": "toolu_1", "name": "submit_post_details", "input": [
                    "landmark": " West Point Lighthouse ",
                    "alt_text": "A white lighthouse stands at the tip of a beach.\n\nLow sun lights the water behind it.",
                    "hashtags": .array(hashtags),
                ]],
            ],
            "stop_reason": "tool_use",
            "usage": ["input_tokens": 2100, "output_tokens": 640, "server_tool_use": ["web_search_requests": 3]],
        ]
    }

    @Test("The request carries the key, the model, both tools and the photo")
    func request() async throws {
        let (draft, usage) = try await client([(200, Self.submitted())])
            .draft(imageJPEG: image, prompt: "Place: Seattle, WA", instructions: "Be helpful.")

        let (request, body) = try #require(StubAnthropic.requests.first)
        #expect(request.url == ClaudeClient.endpoint)
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "test-key")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2026-10-21")
        #expect(request.value(forHTTPHeaderField: "anthropic-beta") == "server-side-fallback-2026-07-01")
        #expect(body["model"] == "claude-sonnet-5-5")
        #expect(body["system"] == "Be helpful.")
        #expect(body["output_config"]?["effort"] == "high")
        #expect(body["tool_choice"]?["type"] == "auto")

        let tools = try #require(body["tools"]?.arrayValue)
        #expect(tools.first?["type"] == "web_search_20260209")
        let submit = try #require(tools.last)
        #expect(submit["name"] == "submit_post_details")
        #expect(submit["strict"] == true)
        #expect(submit["input_schema"]?["additionalProperties"] == false)
        #expect(submit["input_schema"]?["required"] == ["landmark", "alt_text", "hashtags"])

        let content = try #require(body["messages"]?.arrayValue?.first?["content"]?.arrayValue)
        #expect(content.first?["source"]?["media_type"] == "image/jpeg")
        #expect(content.first?["source"]?["data"] == .string(image.base64EncodedString()))
        #expect(content.last?["text"] == "Place: Seattle, WA")

        #expect(draft.landmark == "West Point Lighthouse")
        #expect(draft.altText == "A white lighthouse stands at the tip of a beach. Low sun lights the water behind it.")
        #expect(draft.hashtags == ["#westpointlighthouse", "#discoverypark", "#seattle", "#pnwlighthouses", "#goldenhour"])
        #expect(usage == ClaudeClient.Usage(inputTokens: 2100, outputTokens: 640, webSearches: 3))
    }

    @Test("Hashtags are cleaned and capped at five")
    func hashtags() async throws {
        let (draft, _) = try await client([(200, Self.submitted(["#Seattle", "#seattle", "pnw", "#a", "#b", "#c", "#d", "#e"]))])
            .draft(imageJPEG: image, prompt: "", instructions: "")
        #expect(draft.hashtags == ["#Seattle", "#a", "#b", "#c", "#d"])
    }

    @Test("A paused search is resumed with its content sent back unchanged")
    func pauseTurn() async throws {
        let paused: JSONValue = [
            ["type": "thinking", "thinking": "", "signature": "sig-123"],
            ["type": "server_tool_use", "id": "srvtoolu_1", "name": "web_search", "input": ["query": "west point lighthouse hashtags"]],
        ]
        let (draft, usage) = try await client([
            (200, ["content": paused, "stop_reason": "pause_turn", "usage": ["input_tokens": 100, "output_tokens": 10]]),
            (200, Self.submitted()),
        ]).draft(imageJPEG: image, prompt: "", instructions: "")

        #expect(StubAnthropic.requests.count == 2)
        let messages = try #require(StubAnthropic.requests.last?.body["messages"]?.arrayValue)
        #expect(messages.count == 2)
        #expect(messages[1]["role"] == "assistant")
        #expect(messages[1]["content"] == paused)
        #expect(draft.landmark == "West Point Lighthouse")
        #expect(usage.inputTokens == 2200)
    }

    @Test("Without a submission, Claude is reminded once and then given up on")
    func noAnswer() async throws {
        let chat: JSONValue = ["content": [["type": "text", "text": "Lovely photo!"]], "stop_reason": "end_turn"]
        await #expect(throws: ClaudeClient.Failure.noAnswer) {
            try await client([(200, chat), (200, chat)]).draft(imageJPEG: image, prompt: "", instructions: "")
        }
        #expect(StubAnthropic.requests.count == 2)
        let reminder = try #require(StubAnthropic.requests.last?.body["messages"]?.arrayValue?.last)
        #expect(reminder["role"] == "user")
        #expect(reminder["content"]?.stringValue?.contains("submit_post_details") == true)
    }

    @Test("A rejected key stops right away")
    func keyRejected() async {
        await #expect(throws: ClaudeClient.Failure.keyRejected) {
            try await client([(401, ["type": "error"])]).draft(imageJPEG: image, prompt: "", instructions: "")
        }
        #expect(StubAnthropic.requests.count == 1)
    }

    @Test("A busy service is retried once")
    func overloaded() async throws {
        let (draft, _) = try await client([(529, ["type": "error"]), (200, Self.submitted())])
            .draft(imageJPEG: image, prompt: "", instructions: "")
        #expect(StubAnthropic.requests.count == 2)
        #expect(draft.hashtags.count == 5)

        await #expect(throws: ClaudeClient.Failure.http(529)) {
            try await client([(529, ["type": "error"]), (529, ["type": "error"])]).draft(imageJPEG: image, prompt: "", instructions: "")
        }
    }

    @Test("A refusal ends the request")
    func refusal() async {
        await #expect(throws: ClaudeClient.Failure.refused) {
            try await client([(200, ["content": [], "stop_reason": "refusal"])]).draft(imageJPEG: image, prompt: "", instructions: "")
        }
    }
}

@Suite("Prompt details")
struct PromptTests {
    @Test("Camera details go to Claude only")
    func camera() {
        let context = ImageAnalyzer.Context(place: "Seattle, WA", camera: "NIKON Z 8", exposure: "64 ISO | 35 mm | f/11 | 1/4 s")
        let apple = ImageAnalyzer.prompt(for: context, includeNearby: true)
        let claude = ImageAnalyzer.prompt(for: context, includeNearby: true, includeCamera: true)
        #expect(!apple.contains("NIKON"))
        #expect(claude.contains("Camera: NIKON Z 8"))
        #expect(claude.contains("Exposure: 64 ISO | 35 mm | f/11 | 1/4 s"))
    }
}
