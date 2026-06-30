import SwiftUI

/// First-run onboarding window. Explains why each permission is needed and
/// walks the user through granting Accessibility + setting an API key.
///
/// Presented modally from `MenuBarView` when `settings.hasCompletedOnboarding`
/// is false. Not a separate `Scene` — we keep it as a sheet-style window
/// triggered on demand to avoid App lifecycle complexity.
struct OnboardingView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            Group {
                switch step {
                case 0: welcomeStep
                case 1: accessibilityStep
                case 2: providerStep
                default: doneStep
                }
            }
            footer
        }
        .padding(28)
        .frame(width: 460, height: 360)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading) {
                Text("Welcome to NotchMind").font(.title2.bold())
                Text("Step \(step + 1) of 4").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NotchMind turns your MacBook notch into a live surface for two things:")
                .font(.body)
            VStack(alignment: .leading, spacing: 10) {
                Label("Press ⌥⌘E on any selected text to get an AI explanation in the notch.",
                      systemImage: "text.magnifyingglass")
                Label("Press ⌥⌘C to capture the selection to Markdown in `~/NotchMind/captures/`.",
                      systemImage: "tray.and.arrow.down")
            }
            .font(.callout)
            Spacer()
            Text("Both hotkeys are customizable in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var accessibilityStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grant Accessibility")
                .font(.headline)
            Text("NotchMind reads the currently-selected text directly via macOS's Accessibility API. This is the only way to read a selection without disturbing your clipboard.")
                .font(.callout)
            HStack {
                Button("Open System Settings") { openAccessibilityPane() }
                    .buttonStyle(.borderedProminent)
                if SelectionReader.isAccessibilityEnabled() {
                    Label("Granted", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }
            Spacer()
            Text("If you skip this, NotchMind will fall back to simulating ⌘C and restoring your clipboard afterward — clearly noted in the notch each time.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var providerStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick an LLM")
                .font(.headline)
            Text("Settings → LLM lets you choose OpenAI, Anthropic, or a local Ollama instance. Add your API key there and you're ready.")
                .font(.callout)
            Spacer()
            Text("You can change providers any time. Keys are stored in Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You're set.").font(.title3.bold())
            Text("Select any text and press ⌥⌘E to try it.").font(.body)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
        }
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") { step -= 1 }
            }
            Spacer()
            if step < 3 {
                Button("Next") { step += 1 }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Done") {
                    settings.hasCompletedOnboarding = true
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func openAccessibilityPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
