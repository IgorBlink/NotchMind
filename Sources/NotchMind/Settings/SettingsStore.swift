import Foundation
import Combine

/// User-facing settings backed by `UserDefaults`.
///
/// Stored as `@AppStorage`-friendly raw values so SwiftUI bindings in
/// `SettingsView` can write directly. API keys are NOT stored here — they
/// go through `KeychainStore`.
@MainActor
public final class SettingsStore: ObservableObject {

    public static let shared = SettingsStore()

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.provider:           LLMProvider.openai.rawValue,
            Keys.model:              LLMProvider.openai.defaultModel,
            Keys.baseURL:            LLMProvider.openai.defaultBaseURL,
            Keys.promptTemplate:     PromptTemplates.defaultExplain,
            Keys.captureFolder:      "~/NotchMind/captures",
            Keys.autoDismissSeconds: 18.0,
            Keys.fontSize:           13.0,
            Keys.maxExpandedHeight:  320.0,
            Keys.streamTokens:       true,
            Keys.allowClipboardFallback: true,
            Keys.hasCompletedOnboarding: false,
            Keys.hotkeysPaused:      false
        ])
    }

    public var provider: LLMProvider {
        get { LLMProvider(rawValue: defaults.string(forKey: Keys.provider) ?? "openai") ?? .openai }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.provider)
            // Reset model + baseURL to the new provider's defaults if the user
            // hasn't customized them for that provider yet.
            if defaults.string(forKey: Keys.model + "/" + newValue.rawValue) == nil {
                model = newValue.defaultModel
            }
            if defaults.string(forKey: Keys.baseURL + "/" + newValue.rawValue) == nil {
                baseURL = newValue.defaultBaseURL
            }
        }
    }

    public var model: String {
        get { defaults.string(forKey: Keys.model) ?? LLMProvider.openai.defaultModel }
        set { defaults.set(newValue, forKey: Keys.model) }
    }

    public var baseURL: String {
        get { defaults.string(forKey: Keys.baseURL) ?? LLMProvider.openai.defaultBaseURL }
        set { defaults.set(newValue, forKey: Keys.baseURL) }
    }

    public var promptTemplate: String {
        get { defaults.string(forKey: Keys.promptTemplate) ?? PromptTemplates.defaultExplain }
        set { defaults.set(newValue, forKey: Keys.promptTemplate) }
    }

    public var captureFolder: String {
        get { defaults.string(forKey: Keys.captureFolder) ?? "~/NotchMind/captures" }
        set { defaults.set(newValue, forKey: Keys.captureFolder) }
    }

    public var autoDismissSeconds: Double {
        get { defaults.object(forKey: Keys.autoDismissSeconds) as? Double ?? 18.0 }
        set { defaults.set(newValue, forKey: Keys.autoDismissSeconds) }
    }

    public var fontSize: Double {
        get { defaults.object(forKey: Keys.fontSize) as? Double ?? 13.0 }
        set { defaults.set(newValue, forKey: Keys.fontSize) }
    }

    public var maxExpandedHeight: Double {
        get { defaults.object(forKey: Keys.maxExpandedHeight) as? Double ?? 320.0 }
        set { defaults.set(newValue, forKey: Keys.maxExpandedHeight) }
    }

    public var streamTokens: Bool {
        get { defaults.object(forKey: Keys.streamTokens) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.streamTokens) }
    }

    public var allowClipboardFallback: Bool {
        get { defaults.object(forKey: Keys.allowClipboardFallback) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.allowClipboardFallback) }
    }

    public var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }

    public var hotkeysPaused: Bool {
        get { defaults.bool(forKey: Keys.hotkeysPaused) }
        set { defaults.set(newValue, forKey: Keys.hotkeysPaused) }
    }

    /// Expanded `~` to the user's home directory.
    public var captureFolderPath: String {
        let raw = captureFolder
        if raw.hasPrefix("~") {
            return (raw as NSString).expandingTildeInPath
        }
        return raw
    }

    private enum Keys {
        static let provider           = "notchmind.provider"
        static let model              = "notchmind.model"
        static let baseURL            = "notchmind.baseURL"
        static let promptTemplate     = "notchmind.promptTemplate"
        static let captureFolder      = "notchmind.captureFolder"
        static let autoDismissSeconds = "notchmind.autoDismissSeconds"
        static let fontSize           = "notchmind.fontSize"
        static let maxExpandedHeight  = "notchmind.maxExpandedHeight"
        static let streamTokens       = "notchmind.streamTokens"
        static let allowClipboardFallback = "notchmind.allowClipboardFallback"
        static let hasCompletedOnboarding = "notchmind.hasCompletedOnboarding"
        static let hotkeysPaused      = "notchmind.hotkeysPaused"
    }
}
