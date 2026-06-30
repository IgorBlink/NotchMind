import Combine
import Foundation

/// The orchestrator that ties hotkey → read → context → LLM stream → notch.
///
/// Owned by `AppDelegate`. Holds references to the long-lived services
/// (`NotchViewModel`, `NotchPanelController`, `CaptureStore`, `CaptureIndex`)
/// and exposes the two entry points (`handleExplain()`, `handleCapture()`)
/// that `HotkeyManager` calls on key-up.
@MainActor
public final class AppState: ObservableObject {

    public let settings: SettingsStore
    public let notch: NotchViewModel
    public let notchPanel: NotchPanelController
    public let captureIndex: CaptureIndex
    public let captureStore: CaptureStore
    public let hotkeys: HotkeyManager

    private var currentStreamTask: Task<Void, Never>?

    public init(settings: SettingsStore = .shared) {
        self.settings = settings
        let notch = NotchViewModel()
        self.notch = notch
        self.notchPanel = NotchPanelController(viewModel: notch)

        let indexURL = AppState.defaultIndexURL()
        let index = CaptureIndex(indexURL: indexURL)
        self.captureIndex = index
        self.captureStore = CaptureStore(rootFolder: settings.captureFolder, index: index)
        self.hotkeys = HotkeyManager()
    }

    public func bootstrap() {
        hotkeys.register(onExplain: { [weak self] in self?.handleExplain() },
                         onCapture: { [weak self] in self?.handleCapture() })
    }

    // MARK: - Explain

    public func handleExplain() {
        // Toggle: if the notch is currently showing content, collapse it.
        if notch.toggleOffIfInteractive() { return }

        // Read selection. This must happen on main (AX + pasteboard).
        guard let selection = SelectionReader.readSelectedText(
            allowClipboardFallback: settings.allowClipboardFallback
        ) else {
            notch.noteClipboardFallback(false)
            presentNotch(.error(message: "No text selected. Select text anywhere, then press ⌥⌘E."))
            return
        }
        notch.noteClipboardFallback(selection.source == .clipboardFallback)

        let context = ContextGatherer.gather()
        let prompt = PromptTemplates.render(settings.promptTemplate,
                                            text: selection.text,
                                            context: context.promptString)

        // Show the notch immediately with a loading shimmer.
        notch.showLoading(prompt: "Explaining…")
        notchPanel.show(expandedHeight: max(settings.maxExpandedHeight, 200))

        let provider = settings.provider
        let model = settings.model
        let baseURL = settings.baseURL
        let apiKey = KeychainStore.getAPIKey(for: provider)
        let streamTokens = settings.streamTokens

        currentStreamTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let client = try LLMClientFactory.make(
                    provider: provider, model: model, baseURL: baseURL, apiKey: apiKey
                )
                let messages = [
                    ChatMessage(role: .system, content: "You are a concise, friendly explainer."),
                    ChatMessage(role: .user, content: prompt)
                ]
                if streamTokens {
                    self.notch.beginStreaming(prompt: "Explaining…")
                    for try await delta in client.stream(messages: messages) {
                        try Task.checkCancellation()
                        if !delta.text.isEmpty {
                            self.notch.append(delta.text)
                        }
                        if delta.finished {
                            self.notch.finishStreaming()
                            break
                        }
                    }
                } else {
                    // Collect full response, then show.
                    var text = ""
                    for try await delta in client.stream(messages: messages) {
                        try Task.checkCancellation()
                        text += delta.text
                        if delta.finished { break }
                    }
                    self.notch.beginStreaming(prompt: "")
                    self.notch.append(text)
                    self.notch.finishStreaming()
                }
            } catch is CancellationError {
                // Silent: user dismissed.
            } catch let err as LLMError {
                self.notch.fail(err.localizedDescription)
            } catch {
                self.notch.fail(error.localizedDescription)
            }
        }
        currentStreamTask = task
    }

    // MARK: - Capture

    public func handleCapture() {
        if notch.toggleOffIfInteractive() { return }

        guard let selection = SelectionReader.readSelectedText(
            allowClipboardFallback: settings.allowClipboardFallback
        ) else {
            presentNotch(.error(message: "No text selected. Select text anywhere, then press ⌥⌘C."))
            return
        }
        notch.noteClipboardFallback(selection.source == .clipboardFallback)

        let context = ContextGatherer.gather()

        do {
            let url = try captureStore.save(text: selection.text,
                                             summary: nil,
                                             context: context)
            notch.showToast(message: "Captured to \(url.lastPathComponent)",
                            systemImage: "tray.and.arrow.down.fill")
            notchPanel.show(expandedHeight: 80)

            // Best-effort: generate a one-line summary in the background and
            // update the snippet's frontmatter + index entry.
            generateSummary(for: selection.text, context: context) { [weak self] summary in
                guard let self, let summary else { return }
                self.updateLatestSummary(summary)
            }
        } catch {
            notch.fail("Capture failed: \(error.localizedDescription)")
            notchPanel.show(expandedHeight: 120)
        }
    }

    // MARK: - Notch presentation helper

    public func presentNotch(_ state: NotchState) {
        switch state {
        case .idle:
            notch.dismiss()
        case .loading(let p):
            notch.showLoading(prompt: p)
            notchPanel.show(expandedHeight: max(settings.maxExpandedHeight, 200))
        case .streaming:
            notchPanel.show(expandedHeight: max(settings.maxExpandedHeight, 200))
        case .toast(let m, let img):
            notch.showToast(message: m, systemImage: img)
            notchPanel.show(expandedHeight: 80)
        case .error(let m):
            notch.fail(m)
            notchPanel.show(expandedHeight: 120)
        }
    }

    public func dismissNotch() {
        currentStreamTask?.cancel()
        notch.dismiss()
    }

    // MARK: - Helpers

    private static func defaultIndexURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("NotchMind/index.json")
    }

    private func generateSummary(for text: String,
                                 context: SourceContext,
                                 completion: @escaping (String?) -> Void) {
        let provider = settings.provider
        let model = settings.model
        let baseURL = settings.baseURL
        let apiKey = KeychainStore.getAPIKey(for: provider)
        let prompt = PromptTemplates.render(PromptTemplates.captureSummary,
                                            text: text, context: context.promptString)
        Task {
            do {
                let client = try LLMClientFactory.make(
                    provider: provider, model: model, baseURL: baseURL, apiKey: apiKey
                )
                let messages = [
                    ChatMessage(role: .system, content: "Summarize in one short line."),
                    ChatMessage(role: .user, content: prompt)
                ]
                var out = ""
                for try await delta in client.stream(messages: messages) {
                    out += delta.text
                    if delta.finished { break }
                }
                let cleaned = out
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                await MainActor.run { completion(cleaned.isEmpty ? nil : cleaned) }
            } catch {
                await MainActor.run { completion(nil) }
            }
        }
    }

    /// Update the most-recently-saved snippet's summary in the index. We
    /// intentionally don't rewrite the Markdown file's frontmatter on every
    /// summary to keep I/O cheap; the summary is also written at save time
    /// when available. (Future: lazy rewrite.)
    private func updateLatestSummary(_ summary: String) {
        guard let first = captureIndex.snippets.first else { return }
        let updated = Snippet(
            id: first.id,
            text: first.text,
            summary: summary,
            appName: first.appName,
            appBundleID: first.appBundleID,
            windowTitle: first.windowTitle,
            url: first.url,
            capturedAt: first.capturedAt,
            fileRelativePath: first.fileRelativePath
        )
        captureIndex.upsert(updated)
    }
}
