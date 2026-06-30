import Foundation

/// The notch surface's presentation state.
///
/// Designed as a single-owner state machine: at any time the notch is in
/// exactly one of these states. Transitions are driven by `NotchViewModel`
/// and rendered by `NotchView`. The shape mirrors jackson-storm/DynamicNotch's
/// `NotchEngine` idea (see RESEARCH.md) without copying any code.
public enum NotchState: Sendable, Equatable {
    /// Slim bar hugging the hardware notch (or top-center pill on non-notched
    /// Macs). The resting state.
    case idle

    /// Loading shimmer before the first token arrives.
    case loading(prompt: String)

    /// Streaming an explanation. `text` grows token-by-token; `done` flips to
    /// `true` on the final delta so the view can swap the loading shimmer for
    /// a dismiss affordance.
    case streaming(text: String, done: Bool)

    /// Short confirmation toast for capture. Auto-dismisses.
    case toast(message: String, systemImage: String)

    /// Error surfaced inline. Dismisses on tap or hotkey.
    case error(message: String)

    public var isInteractive: Bool {
        switch self {
        case .idle: return false
        default:    return true
        }
    }
}
