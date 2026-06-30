import Combine
import Foundation
import KeyboardShortcuts

/// Registers the two global hotkeys via `KeyboardShortcuts` and routes their
/// key-up events to `AppState`. Pausing is honored so the user can temporarily
/// disable both hotkeys from the menu-bar dropdown.
@MainActor
public final class HotkeyManager: ObservableObject {

    public typealias Action = () -> Void

    private var explainAction: Action?
    private var captureAction: Action?

    public init() {}

    /// Wire the hotkeys. Call once from `AppDelegate.applicationDidFinishLaunching`.
    public func register(onExplain: @escaping Action, onCapture: @escaping Action) {
        self.explainAction = onExplain
        self.captureAction = onCapture

        KeyboardShortcuts.onKeyUp(for: .explain) { [weak self] in
            guard let self else { return }
            guard !SettingsStore.shared.hotkeysPaused else { return }
            self.explainAction?()
        }
        KeyboardShortcuts.onKeyUp(for: .capture) { [weak self] in
            guard let self else { return }
            guard !SettingsStore.shared.hotkeysPaused else { return }
            self.captureAction?()
        }
    }

    /// Pause/unpause both hotkeys. Bound from the menu-bar dropdown.
    public func setPaused(_ paused: Bool) {
        SettingsStore.shared.hotkeysPaused = paused
        objectWillChange.send()
    }

    public var isPaused: Bool {
        SettingsStore.shared.hotkeysPaused
    }
}
