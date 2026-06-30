import Foundation

/// A single LLM chat message in the provider-agnostic shape used across
/// `LLMClient` implementations.
public struct ChatMessage: Sendable, Equatable {
    public let role: Role
    public var content: String

    public enum Role: String, Sendable, Equatable {
        case system
        case user
        case assistant
    }

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

/// A token (or token-batch) yielded by a streaming completion.
public struct StreamDelta: Sendable, Equatable {
    /// The text fragment to append to the running output.
    public let text: String
    /// `true` when the stream has finished (the provider's terminal sentinel
    /// was seen). After a `finished` delta, the stream terminates.
    public let finished: Bool

    public init(text: String, finished: Bool = false) {
        self.text = text
        self.finished = finished
    }
}

public enum LLMError: LocalizedError, Sendable {
    case missingAPIKey
    case invalidBaseURL(String)
    case badStatus(Int, String)
    case decoding(Error)
    case cancelled
    case provider(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key set. Open NotchMind → Settings and add one."
        case .invalidBaseURL(let s):
            return "Invalid base URL: \(s)"
        case .badStatus(let code, let body):
            let snippet = body.prefix(280)
            return "Provider returned HTTP \(code): \(snippet)"
        case .decoding(let err):
            return "Could not parse provider response: \(err.localizedDescription)"
        case .cancelled:
            return "Request cancelled."
        case .provider(let s):
            return s
        }
    }
}

/// Provider-agnostic streaming chat client.
///
/// Implementations: `OpenAIClient`, `AnthropicClient`, `OllamaClient`.
/// Each turns a `ChatMessage` list into an `AsyncThrowingStream` of
/// `StreamDelta`s via `URLSession.bytes(for:)`.
public protocol LLMClient: Sendable {
    /// Stream a chat completion. The first delta may be empty (some
    /// providers send a role-only chunk first); callers should append
    /// `text` and treat `finished` as the terminal signal.
    func stream(messages: [ChatMessage]) -> AsyncThrowingStream<StreamDelta, Error>
}

/// Factory: build the right client for the current settings + keychain.
public enum LLMClientFactory {
    public static func make(
        provider: LLMProvider,
        model: String,
        baseURL: String,
        apiKey: String?
    ) throws -> LLMClient {
        switch provider {
        case .openai:
            guard let apiKey, !apiKey.isEmpty else { throw LLMError.missingAPIKey }
            return OpenAIClient(apiKey: apiKey, model: model, baseURL: baseURL)
        case .anthropic:
            guard let apiKey, !apiKey.isEmpty else { throw LLMError.missingAPIKey }
            return AnthropicClient(apiKey: apiKey, model: model, baseURL: baseURL)
        case .ollama:
            return OllamaClient(model: model, baseURL: baseURL)
        }
    }
}
