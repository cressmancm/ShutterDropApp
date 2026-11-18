import Foundation
import OSLog

/// Talks to Anthropic's Messages API with the user's own key. One photo is
/// one conversation: Claude looks at the photo, searches the web for
/// hashtags, and answers by calling `submit_post_details`.
nonisolated struct ClaudeClient: Sendable {
    enum Failure: Error, Equatable {
        /// 401 or 403: the key is wrong, revoked or out of credit.
        case keyRejected
        /// Any other HTTP status after the retry.
        case http(Int)
        /// Claude declined the request.
        case refused
        /// Claude never called `submit_post_details`.
        case noAnswer
        case badResponse
    }

    /// Tokens and searches across the whole conversation, for the log.
    struct Usage: Sendable, Equatable {
        var inputTokens = 0
        var outputTokens = 0
        var webSearches = 0
    }

    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let model = "claude-sonnet-5-5"
    static let submitTool = "submit_post_details"
    /// Requests per photo, counting resumed searches and one reminder.
    static let maxRequests = 4

    let apiKey: String
    var session: URLSession = .shared
    /// The wait before retrying a busy or failed request.
    var retryDelay: Duration = .seconds(2)

    /// Sends the photo and its details, and returns what Claude submitted.
    func draft(imageJPEG: Data, prompt: String, instructions: String) async throws -> (draft: ImageAnalyzer.Draft, usage: Usage) {
        var messages: [JSONValue] = [.object([
            "role": "user",
            "content": [
                ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": .string(imageJPEG.base64EncodedString())]],
                ["type": "text", "text": .string(prompt)],
            ],
        ])]
        var usage = Usage()
        var reminded = false

        for _ in 0..<Self.maxRequests {
            let response = try await send(Self.body(messages: messages, instructions: instructions))
            usage.add(response["usage"])
            let content = response["content"]?.arrayValue ?? []

            if let input = content.first(where: { $0["type"]?.stringValue == "tool_use" && $0["name"]?.stringValue == Self.submitTool })?["input"] {
                return (try Self.draft(from: input), usage)
            }
            // Content goes back exactly as it came, so thinking blocks and
            // paused searches stay valid.
            switch response["stop_reason"]?.stringValue {
            case "pause_turn":
                messages.append(["role": "assistant", "content": .array(content)])
            case "refusal":
                throw Failure.refused
            default:
                guard !reminded else { throw Failure.noAnswer }
                reminded = true
                messages.append(["role": "assistant", "content": .array(content)])
                messages.append(["role": "user", "content": .string("Call \(Self.submitTool) now with the place, the alt text and five hashtags.")])
            }
        }
        throw Failure.noAnswer
    }

    static func body(messages: [JSONValue], instructions: String) -> JSONValue {
        [
            "model": .string(model),
            "max_tokens": 16000,
            "system": .string(instructions),
            "output_config": ["effort": "high"],
            // On a refusal, Anthropic retries on another model in the same request.
            "fallbacks": "default",
            "tools": [
                ["type": "web_search_20260209", "name": "web_search", "max_uses": 5],
                [
                    "name": .string(submitTool),
                    "description": "Submit the finished place name, alt text and hashtags for the photo. Call this once, after your research.",
                    "strict": true,
                    "input_schema": [
                        "type": "object",
                        "properties": [
                            "landmark": ["type": "string", "description": "The most specific place the photo shows, without the city or state. Empty when the city alone is the best answer."],
                            "alt_text": ["type": "string", "description": "Two or three sentences of alt text, as one paragraph."],
                            "hashtags": ["type": "array", "items": ["type": "string"], "description": "Exactly five hashtags, lowercase, each starting with #."],
                        ],
                        "required": ["landmark", "alt_text", "hashtags"],
                        "additionalProperties": false,
                    ],
                ],
            ],
            // Forcing the tool isn't allowed on this model; the instructions ask for it.
            "tool_choice": ["type": "auto"],
            "messages": .array(messages),
        ]
    }

    static func draft(from input: JSONValue) throws -> ImageAnalyzer.Draft {
        guard let landmark = input["landmark"]?.stringValue,
              let altText = input["alt_text"]?.stringValue,
              let tags = input["hashtags"]?.arrayValue
        else { throw Failure.badResponse }
        let hashtags = Hashtags.extract(from: tags.compactMap(\.stringValue).joined(separator: " "))
        return ImageAnalyzer.Draft(
            landmark: landmark.trimmed,
            altText: ImageAnalyzer.paragraph(altText),
            hashtags: Array(hashtags.prefix(5))
        )
    }

    private func send(_ body: JSONValue) async throws -> JSONValue {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 180)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONEncoder().encode(body)

        var retried = false
        while true {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200:
                guard let json = try? JSONDecoder().decode(JSONValue.self, from: data) else { throw Failure.badResponse }
                return json
            case 401, 403:
                throw Failure.keyRejected
            case 429 where !retried, 500...599 where !retried:
                retried = true
                Log.claude.info("Claude answered \(status, privacy: .public); retrying once")
                try await Task.sleep(for: retryDelay)
            default:
                throw Failure.http(status)
            }
        }
    }
}

nonisolated extension ClaudeClient.Usage {
    mutating func add(_ usage: JSONValue?) {
        inputTokens += usage?["input_tokens"]?.intValue ?? 0
        outputTokens += usage?["output_tokens"]?.intValue ?? 0
        webSearches += usage?["server_tool_use"]?["web_search_requests"]?.intValue ?? 0
    }
}

/// Any JSON value, so a response's content blocks can be sent back as they came.
nonisolated enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value):
            if value == value.rounded(), abs(value) < 1e15 { try container.encode(Int64(value)) } else { try container.encode(value) }
        case .bool(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let object) = self { object[key] } else { nil }
    }

    var stringValue: String? {
        if case .string(let value) = self { value } else { nil }
    }

    var intValue: Int? {
        if case .number(let value) = self { Int(value) } else { nil }
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { value } else { nil }
    }
}

nonisolated extension JSONValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral,
                     ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .number(Double(value)) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
    init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    init(dictionaryLiteral elements: (String, JSONValue)...) { self = .object(Dictionary(uniqueKeysWithValues: elements)) }
}
