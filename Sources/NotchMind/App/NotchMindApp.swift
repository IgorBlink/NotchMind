import SwiftUI

/// App entry point.
///
/// `LSUIElement = true` (Info.plist) keeps NotchMind out of the Dock. The
/// user-facing surface is `MenuBarExtra` (the dropdown) plus the notch panel
/// owned by `AppDelegate.appState.notchPanel`.
@main
struct NotchMindApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appDelegate.appState)
                .environmentObject(appDelegate.appState.notch)
                .environmentObject(appDelegate.appState.captureIndex)
                .environmentObject(appDelegate.appState.hotkeys)
                .environmentObject(settings)
        } label: {
            Image(systemName: "brain.head.profile")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
                .environmentObject(settings)
        }
    }
}
