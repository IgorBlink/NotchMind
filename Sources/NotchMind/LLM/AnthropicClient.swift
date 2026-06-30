import Foundation

/// Anthropic Messages API streaming client.
///
/// Endpoint: `{baseURL}/messages` with `stream: true`. Response is SSE with
/// *named* events: `content_block_delta` carries `delta.text`; `message_stop`
/// ends the stream. Requires `x-api-key`, `anthropic-version: 2023-06-01`,
/// and `Content-Type: application/json`.
///
/// Unlike OpenAI, Anthropic takes `system` as a top-level field, not inside
/// `messages`. We lift the first `system` message out of the array.
public struct AnthropicClient: LLMClient {
    public let apiKey: String
    public let model: String
    public let baseURL: String
    public let session: URLSession
    private let apiVersion = "2023-06-01"

    public init(apiKey: String, model: String, baseURL: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.session = session
    }

    public func stream(messages: [ChatMessage]) -> AsyncThrowingStream<StreamDelta, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(messages: messages)
                    let (bytes, response) = try await session.bytes(for: request)
                    try Self.check(response: response)
                    var pendingEvent: String?
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        if let event = SSEParser.event(from: line) {
                            pendingEvent = event
                            continue
                        }
                        guard let payload = SSEParser.dataPayload(from: line),
                              payload != String.doneSentinel,
                              let data = payload.data(using: .utf8) else { continue }
                        let event = pendingEvent
                        switch event {
                        case "content_block_delta":
                            if let delta = try? JSONDecoder().decode(ContentDelta.self, from: data) {
                                if let text = delta.delta?.text, !text.isEmpty {
                                    continuation.yield(StreamDelta(text: text))
                                }
                            }
                        case "message_stop":
                            continuation.yield(StreamDelta(text: "", finished: true))
                            return
                        default:
                            break
                        }
                    }
                    continuation.yield(StreamDelta(text: "", finished: true))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: LLMError.cancelled)
                } catch let err as LLMError {
                    continuation.finish(throwing: err)
                } catch {
                    continuation.finish(throwing: LLMError.decoding(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func makeRequest(messages: [ChatMessage]) throws -> URLRequest {
        guard let url = URL(string: baseURL + "/messages") else {
            throw LLMError.invalidBaseURL(baseURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 60

        // Lift the system message out of the array per Anthropic's schema.
        let system = messages.first { $0.role == .system }?.content
        let convo = messages.filter { $0.role != .system }

        var body: [String: Any] = [
            "model": model,
            "messages": convo.map { ["role": $0.role.rawValue, "content": $0.content] },
            "stream": true,
            "max_tokens": 1024
        ]
        if let system { body["system"] = system }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    static func check(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.provider("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LLMError.badStatus(http.statusCode, "Anthropic error")
        }
    }

    private struct ContentDelta: Decodable {
        let delta: Delta?
        struct Delta: Decodable {
            let text: String?
            let type: String?
        }
    }
}
