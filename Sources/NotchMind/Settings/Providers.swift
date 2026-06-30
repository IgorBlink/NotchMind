import Foundation

/// The LLM provider the user has chosen to power explanations.
///
/// Keep this type pure-data (no AppKit/SwiftUI imports) so it's usable from
/// background tasks and the SPM CLI target without dragging in UI frameworks.
public enum LLMProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case openai
    case anthropic
    case ollama

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openai:    return "OpenAI"
        case .anthropic: return "Anthropic"
        case .ollama:    return "Ollama (local)"
        }
    }

    /// Whether this provider needs an API key. Ollama runs locally and does not.
    public var requiresAPIKey: Bool {
        self != .ollama
    }

    /// Default model identifier to pre-fill in Settings on first run.
    public var defaultModel: String {
        switch self {
        case .openai:    return "gpt-4o-mini"
        case .anthropic: return "claude-3-5-haiku-latest"
        case .ollama:    return "llama3.2"
        }
    }

    /// Default base URL. Override in Settings to point at a proxy or self-host.
    public var defaultBaseURL: String {
        switch self {
        case .openai:    return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .ollama:    return "http://localhost:11434"
        }
    }
}
