import Foundation

/// OpenAI Chat Completions streaming client.
///
/// Endpoint: `{baseURL}/chat/completions` with `stream: true`. Response is
/// SSE; each `data:` line is a JSON chunk with
/// `choices[0].delta.content`. Stream ends with `data: [DONE]`.
///
/// See RESEARCH.md §5 for the pattern provenance.
public struct OpenAIClient: LLMClient {
    public let apiKey: String
    public let model: String
    public let baseURL: String
    public let session: URLSession

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
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard let payload = SSEParser.dataPayload(from: line) else { continue }
                        if payload == String.doneSentinel {
                            continuation.yield(StreamDelta(text: "", finished: true))
                            return
                        }
                        guard let data = payload.data(using: .utf8) else { continue }
                        let chunk = try JSONDecoder().decode(Chunk.self, from: data)
                        if chunk.choices.first?.finishReason != nil {
                            continuation.yield(StreamDelta(text: chunk.choices.first?.delta?.content ?? "",
                                                           finished: true))
                            return
                        }
                        let text = chunk.choices.first?.delta?.content ?? ""
                        if !text.isEmpty {
                            continuation.yield(StreamDelta(text: text))
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
        guard let url = URL(string: baseURL + "/chat/completions") else {
            throw LLMError.invalidBaseURL(baseURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "stream": true
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    static func check(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.provider("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            // Best-effort: capture the body via the AsyncBytes stream is awkward
            // here; surface the status code and let the caller retry.
            throw LLMError.badStatus(http.statusCode, "OpenAI error")
        }
    }

    // MARK: - Decodable chunk shape

    private struct Chunk: Decodable {
        let choices: [Choice]
        struct Choice: Decodable {
            let delta: Delta?
            let finishReason: String?
            enum CodingKeys: String, CodingKey {
                case delta
                case finishReason = "finish_reason"
            }
        }
        struct Delta: Decodable {
            let content: String?
        }
    }
}
