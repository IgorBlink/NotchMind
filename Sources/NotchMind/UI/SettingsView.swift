import KeyboardShortcuts
import SwiftUI

/// The settings window. Provider/model/API key, hotkey recorders, prompt
/// template, capture folder, notch behavior.
struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var apiKey: String = ""
    @State private var showSavedToast: Bool = false

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gearshape") }
            llmTab.tabItem { Label("LLM", systemImage: "cpu") }
            hotkeysTab.tabItem { Label("Hotkeys", systemImage: "keyboard") }
            captureTab.tabItem { Label("Capture", systemImage: "tray.and.arrow.down") }
            notchTab.tabItem { Label("Notch", systemImage: "rectangle.topthird.inset.filled") }
        }
        .frame(width: 560, height: 480)
        .onAppear { reloadAPIKey() }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Onboarding") {
                Toggle("Has completed onboarding", isOn: Binding(
                    get: { settings.hasCompletedOnboarding },
                    set: { settings.hasCompletedOnboarding = $0 }
                ))
            }
            Section("Accessibility") {
                HStack {
                    Image(systemName: SelectionReader.isAccessibilityEnabled()
                          ? "checkmark.seal.fill" : "exclamationmark.shield.fill")
                        .foregroundStyle(SelectionReader.isAccessibilityEnabled() ? .green : .orange)
                    Text(SelectionReader.isAccessibilityEnabled()
                         ? "Accessibility permission granted"
                         : "Accessibility not granted — clipboard fallback active")
                        .font(.callout)
                }
                Button("Open System Settings → Privacy & Security → Accessibility") {
                    openAccessibilityPane()
                }
            }
        }
        .padding()
    }

    // MARK: - LLM

    private var llmTab: some View {
        Form {
            Section("Provider") {
                Picker("Provider", selection: Binding(
                    get: { settings.provider },
                    set: { settings.provider = $0; reloadAPIKey() }
                )) {
                    ForEach(LLMProvider.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Model") {
                TextField("Model", text: Binding(
                    get: { settings.model },
                    set: { settings.model = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }

            Section("Base URL") {
                TextField("Base URL", text: Binding(
                    get: { settings.baseURL },
                    set: { settings.baseURL = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                Text("Leave as the default unless you use a proxy or self-host.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settings.provider.requiresAPIKey {
                Section("API Key") {
                    SecureField("API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Save to Keychain") {
                            try? KeychainStore.setAPIKey(apiKey, for: settings.provider)
                            showSavedToast = true
                            apiKey = ""
                            reloadAPIKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKey.isEmpty)
                        Spacer()
                        Button("Remove") {
                            KeychainStore.deleteAPIKey(for: settings.provider)
                            reloadAPIKey()
                        }
                        .buttonStyle(.bordered)
                    }
                    if showSavedToast {
                        Text("Saved ✓").font(.caption).foregroundStyle(.green)
                    }
                }
            }

            Section("Prompt Template") {
                TextEditor(text: Binding(
                    get: { settings.promptTemplate },
                    set: { settings.promptTemplate = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 110)
                Text("Placeholders: {text} and {context}.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Hotkeys

    private var hotkeysTab: some View {
        Form {
            Section("Hotkeys") {
                HStack {
                    Text("Explain")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .explain)
                }
                HStack {
                    Text("Capture")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .capture)
                }
            }
            Section("Behavior") {
                Toggle("Allow clipboard fallback when Accessibility fails", isOn: Binding(
                    get: { settings.allowClipboardFallback },
                    set: { settings.allowClipboardFallback = $0 }
                ))
                Text("When on, NotchMind will simulate ⌘C and read the pasteboard as a last resort. Your clipboard is restored afterward.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Capture

    private var captureTab: some View {
        Form {
            Section("Destination") {
                TextField("Capture folder", text: Binding(
                    get: { settings.captureFolder },
                    set: { settings.captureFolder = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                Text("Markdown files are written to `<folder>/YYYY-MM/…md`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [URL(fileURLWithPath: settings.captureFolderPath)]
                    )
                }
            }
        }
        .padding()
    }

    // MARK: - Notch

    private var notchTab: some View {
        Form {
            Section("Display") {
                Slider(value: Binding(
                    get: { settings.fontSize },
                    set: { settings.fontSize = $0 }
                ), in: 10...18, step: 0.5) {
                    Text("Font size")
                } minimumValueLabel: {
                    Text("10").font(.caption2)
                } maximumValueLabel: {
                    Text("18").font(.caption2)
                }

                Slider(value: Binding(
                    get: { settings.maxExpandedHeight },
                    set: { settings.maxExpandedHeight = $0 }
                ), in: 160...480, step: 10) {
                    Text("Max expanded height")
                } minimumValueLabel: {
                    Text("160").font(.caption2)
                } maximumValueLabel: {
                    Text("480").font(.caption2)
                }
            }

            Section("Behavior") {
                Toggle("Stream tokens live", isOn: Binding(
                    get: { settings.streamTokens },
                    set: { settings.streamTokens = $0 }
                ))
                HStack {
                    Text("Auto-dismiss after")
                    Spacer()
                    TextField("",
                              value: Binding(
                                get: { settings.autoDismissSeconds },
                                set: { settings.autoDismissSeconds = $0 }
                              ),
                              format: .number)
                        .frame(width: 60)
                    Text("seconds")
                }
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func reloadAPIKey() {
        apiKey = KeychainStore.getAPIKey(for: settings.provider) ?? ""
    }

    private func openAccessibilityPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
