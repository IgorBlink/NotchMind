import AppKit
import Foundation

/// Owns long-lived services that need an `NSApplication` reference and routes
/// accessibility / URL-string deep links.
///
/// NotchMind uses `LSUIElement = true` (no Dock icon) + `MenuBarExtra` for
/// the dropdown. `AppDelegate` handles the parts `MenuBarExtra` can't:
/// listening for screen changes, prompting for Accessibility on first run,
/// and exposing the `AppState` to SwiftUI via `@EnvironmentObject`.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {

    public let appState: AppState

    public override init() {
        self.appState = AppState()
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        appState.bootstrap()

        // First-run: prompt for Accessibility. The user can deny and still use
        // the clipboard fallback path.
        if !SelectionReader.isAccessibilityEnabled() {
            SelectionReader.promptAccessibility()
        }

        // Bring the menu-bar item online. SwiftUI's `MenuBarExtra` declared in
        // `NotchMindApp` will own its lifecycle; we just make sure the app is
        // ready to serve hotkey events.
        NSApp.setActivationPolicy(.accessory)
    }

    public func applicationWillTerminate(_ notification: Notification) {
        appState.dismissNotch()
    }
}
