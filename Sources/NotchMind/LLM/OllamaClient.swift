import Foundation

/// Ollama chat streaming client (local).
///
/// Endpoint: `{baseURL}/api/chat` with `stream: true`. Unlike OpenAI/
/// Anthropic, Ollama returns **NDJSON** (one JSON object per line, no
/// `data:` prefix). Each line has `message.content`; the final line has
/// `"done": true`. No API key required.
public struct OllamaClient: LLMClient {
    public let model: String
    public let baseURL: String
    public let session: URLSession

    public init(model: String, baseURL: String = "http://localhost:11434", session: URLSession = .shared) {
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
                        guard let data = line.data(using: .utf8) else { continue }
                        guard let chunk = try? JSONDecoder().decode(Chunk.self, from: data) else { continue }
                        let text = chunk.message?.content ?? ""
                        if !text.isEmpty {
                            continuation.yield(StreamDelta(text: text))
                        }
                        if chunk.done {
                            continuation.yield(StreamDelta(text: "", finished: true))
                            return
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
        guard let url = URL(string: baseURL + "/api/chat") else {
            throw LLMError.invalidBaseURL(baseURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 120  // local models can be slow to first token

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
            let hint = http.statusCode == 404
                ? " — is Ollama running at \(URL(string: "http://localhost:11434")!.absoluteString)?"
                : ""
            throw LLMError.badStatus(http.statusCode, "Ollama error\(hint)")
        }
    }

    private struct Chunk: Decodable {
        let message: Message?
        let done: Bool
        struct Message: Decodable {
            let content: String?
        }
    }
}
