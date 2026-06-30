import KeyboardShortcuts
import Foundation

/// Names of the two global hotkeys. Defaults match the spec: ⌥⌘E and ⌥⌘C.
///
/// `KeyboardShortcuts` persists user-recorded overrides in `UserDefaults`
/// automatically; we never touch the storage directly.
public extension KeyboardShortcuts.Name {
    /// "Explain" — read selection, stream an AI explanation into the notch.
    static let explain = Self(
        "explain",
        default: .init(.e, modifiers: [.option, .command])
    )

    /// "Capture" — save the selection to `~/NotchMind/captures/` as Markdown.
    static let capture = Self(
        "capture",
        default: .init(.c, modifiers: [.option, .command])
    )
}
