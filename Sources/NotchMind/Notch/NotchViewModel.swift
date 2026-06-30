import Combine
import Foundation

/// Single-owner state machine for the notch surface.
///
/// Owns the current `NotchState`, manages auto-dismiss timers, and exposes
/// the running explanation text. `NotchPanelController` hosts a SwiftUI view
/// that observes this. All mutations happen on the main actor.
@MainActor
public final class NotchViewModel: ObservableObject {

    @Published public private(set) var state: NotchState = .idle
    @Published public private(set) var usedClipboardFallback: Bool = false

    /// Set to `true` to make `NotchView` show a "used clipboard" footnote.
    public func noteClipboardFallback(_ value: Bool) {
        usedClipboardFallback = value
    }

    public init() {}

    // MARK: - Transitions

    public func showLoading(prompt: String) {
        cancelDismiss()
        state = .loading(prompt: prompt)
    }

    public func beginStreaming(prompt: String) {
        cancelDismiss()
        state = .streaming(text: "", done: false)
    }

    public func append(_ delta: String) {
        guard case .streaming(let text, let done) = state, !done else { return }
        state = .streaming(text: text + delta, done: false)
    }

    public func finishStreaming() {
        guard case .streaming(let text, _) = state else { return }
        state = .streaming(text: text, done: true)
        scheduleAutoDismiss()
    }

    public func fail(_ message: String) {
        cancelDismiss()
        state = .error(message: message)
        scheduleAutoDismiss(seconds: 12)
    }

    public func showToast(message: String, systemImage: String = "checkmark.circle.fill") {
        cancelDismiss()
        state = .toast(message: message, systemImage: systemImage)
        scheduleAutoDismiss(seconds: 3.5)
    }

    public func dismiss() {
        cancelDismiss()
        usedClipboardFallback = false
        state = .idle
    }

    /// If the notch is currently showing content for the given trigger,
    /// collapse it. Used so a second press of the hotkey toggles the panel.
    public func toggleOffIfInteractive() -> Bool {
        if state.isInteractive {
            dismiss()
            return true
        }
        return false
    }

    // MARK: - Auto-dismiss

    private var dismissWorkItem: DispatchWorkItem?

    public func scheduleAutoDismiss(seconds: Double? = nil) {
        let delay = seconds ?? SettingsStore.shared.autoDismissSeconds
        cancelDismiss()
        let work = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    public func cancelDismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
    }

    /// Reset the auto-dismiss timer (e.g. when the user interacts).
    public func resetAutoDismiss() {
        if state.isInteractive && !(dismissWorkItem == nil) {
            scheduleAutoDismiss()
        }
    }
}
