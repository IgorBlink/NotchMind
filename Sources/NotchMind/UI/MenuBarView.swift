import KeyboardShortcuts
import SwiftUI

/// The menu-bar dropdown. Lives in `MenuBarExtra` and surfaces:
/// - Accessibility / onboarding status
/// - Recent captures (click to reveal in Finder)
/// - Pause / resume hotkeys
/// - Settings + Quit
struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var captureIndex: CaptureIndex
    @EnvironmentObject private var hotkeys: HotkeyManager
    @EnvironmentObject private var settings: SettingsStore

    @State private var query: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !settings.hasCompletedOnboarding {
                onboardingBanner
            }

            accessibilityStatus

            capturesSection

            Divider()
            actionsRow
        }
        .padding(.vertical, 8)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.tint)
            Text("NotchMind")
                .font(.headline)
            Spacer()
            Text("⌥⌘E explain · ⌥⌘C capture")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var onboardingBanner: some View {
        Link(destination: URL(string: "notchmind://onboarding")!) {
            Label("Finish setup →", systemImage: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    private var accessibilityStatus: some View {
        HStack(spacing: 6) {
            Image(systemName: SelectionReader.isAccessibilityEnabled()
                  ? "checkmark.seal.fill"
                  : "exclamationmark.shield.fill")
                .foregroundStyle(SelectionReader.isAccessibilityEnabled() ? .green : .orange)
            Text(SelectionReader.isAccessibilityEnabled()
                 ? "Accessibility granted"
                 : "Accessibility not granted — using clipboard fallback")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            if !SelectionReader.isAccessibilityEnabled() {
                Button("Grant") { SelectionReader.promptAccessibility() }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
    }

    private var capturesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Recent captures")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if !captureIndex.snippets.isEmpty {
                    Text("\(captureIndex.snippets.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            TextField("Search captures…", text: $query)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
            CapturesListView(query: query)
                .frame(maxHeight: 180)
        }
    }

    private var actionsRow: some View {
        HStack {
            Button(hotkeys.isPaused ? "Resume hotkeys" : "Pause hotkeys") {
                hotkeys.setPaused(!hotkeys.isPaused)
            }
            .buttonStyle(.bordered)
            Spacer()
            Button("Settings") { openSettingsScene() }
                .buttonStyle(.bordered)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.bordered)
        }
    }
}

/// Opens the SwiftUI `Settings` scene on macOS 13 and 14+. The action selector
/// was renamed in macOS 14; the old name still resolves on both.
private func openSettingsScene() {
    if #available(macOS 14.0, *) {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    } else {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}
