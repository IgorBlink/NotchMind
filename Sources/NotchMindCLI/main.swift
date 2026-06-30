// NotchMind CLI — a headless entry point for `swift run` / `swift build`.
//
// The real app is built from `NotchMind.xcodeproj` (see BUILD.md). This CLI
// exists so contributors can type-check the core library without Xcode and
// exercise the LLM/capture paths from the terminal:
//
//   notchmind-cli explain "zeitgeist" --provider ollama
//   notchmind-cli explain "zeitgeist" --provider openai --api-key sk-...
//   notchmind-cli capture "a snippet to remember"
//   notchmind-cli list
//
// It only depends on `NotchMindCore`, which is the same Swift code the app
// target compiles. We parse argv by hand to keep the dependency surface
// minimal — the CLI is a dev convenience, not a shipped artifact.

import Foundation
import NotchMindCore

@main
enum NotchMindCLI {
    static func main() async {
        let argv = CommandLine.arguments
        let binary = (argv.first as NSString?)?.lastPathComponent ?? "notchmind-cli"
        let args = Array(argv.dropFirst())

        let parsed = ParsedArgs.parse(args)
        do {
            try await run(parsed: parsed)
        } catch {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            exit(64)
        }
    }

    static func run(parsed: ParsedArgs) async throws {
        switch parsed.action {
        case nil, "help", "--help", "-h":
            printHelp()
        case "explain":
            try await runExplain(parsed)
        case "capture":
            try await runCapture(parsed)
        case "list":
            try await runList(parsed)
        case let unknown?:
            throw CleanError.message("Unknown action: \(unknown). Use explain | capture | list.")
        }
    }

    // MARK: - Actions

    static func runExplain(_ p: ParsedArgs) async throws {
        let provider = LLMProvider(rawValue: p.provider) ?? .ollama
        let model = p.model ?? provider.defaultModel
        let baseURL = p.baseURL ?? provider.defaultBaseURL
        let apiKey = p.apiKey ?? KeychainStore.getAPIKey(for: provider)

        let client = try LLMClientFactory.make(
            provider: provider, model: model, baseURL: baseURL, apiKey: apiKey
        )
        let prompt = PromptTemplates.render(
            PromptTemplates.defaultExplain, text: p.text, context: "(cli)"
        )
        let messages = [
            ChatMessage(role: .system, content: "You are a concise, friendly explainer."),
            ChatMessage(role: .user, content: prompt)
        ]
        for try await delta in client.stream(messages: messages) {
            print(delta.text, terminator: "")
            fflush(stdout)
            if delta.finished { break }
        }
        print()
    }

    static func runCapture(_ p: ParsedArgs) async throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let indexURL = home.appendingPathComponent("NotchMind/index.json")
        let text = p.text
        let url = try await MainActor.run {
            let index = CaptureIndex(indexURL: indexURL)
            let store = CaptureStore(
                rootFolder: home.appendingPathComponent("NotchMind/captures").path,
                index: index
            )
            let context = SourceContext(appName: "CLI", appBundleID: nil,
                                        windowTitle: nil, url: nil)
            return try store.save(text: text, summary: nil, context: context)
        }
        print("Captured to \(url.path)")
    }

    static func runList(_ p: ParsedArgs) async throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let indexURL = home.appendingPathComponent("NotchMind/index.json")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            print("(no captures)")
            return
        }
        let lines = try await MainActor.run {
            let index = CaptureIndex(indexURL: indexURL)
            return index.snippets.prefix(20).map { s -> String in
                let preview = (s.summary ?? String(s.text.prefix(50)))
                return "[\(s.capturedAtISO)] \(preview)"
            }
        }
        for line in lines { print(line) }
    }

    // MARK: - Arg parsing

    struct ParsedArgs {
        var action: String?
        var text: String = ""
        var provider: String = "ollama"
        var model: String?
        var baseURL: String?
        var apiKey: String?

        static func parse(_ args: [String]) -> ParsedArgs {
            var p = ParsedArgs()
            var positional: [String] = []
            var i = 0
            while i < args.count {
                let a = args[i]
                if a == "--provider" { p.provider = next(args, &i); continue }
                if a == "--model"    { p.model = next(args, &i); continue }
                if a == "--base-url" { p.baseURL = next(args, &i); continue }
                if a == "--api-key"  { p.apiKey = next(args, &i); continue }
                if a == "--help" || a == "-h" { p.action = "help"; continue }
                if a.hasPrefix("--provider=")  { p.provider = String(a.dropFirst(10)); continue }
                if a.hasPrefix("--model=")     { p.model = String(a.dropFirst(8)); continue }
                if a.hasPrefix("--base-url=")  { p.baseURL = String(a.dropFirst(11)); continue }
                if a.hasPrefix("--api-key=")   { p.apiKey = String(a.dropFirst(10)); continue }
                positional.append(a)
                i += 1
            }
            if p.action != "help" {
                p.action = positional.first
            }
            if positional.count > 1 {
                p.text = positional.dropFirst().joined(separator: " ")
            }
            return p
        }

        /// Return the argument after the current index, advancing past it.
        /// If there is no next argument, return an empty string (the action
        /// will surface a clear error downstream).
        static func next(_ args: [String], _ i: inout Int) -> String {
            i += 1
            defer { i += 1 }
            return i < args.count ? args[i] : ""
        }
    }

    static func printHelp() {
        print("""
        NotchMind headless runner — exercise the core library from the terminal.

        Usage:
          notchmind-cli explain <text> [--provider openai|anthropic|ollama] [--model <m>] [--base-url <u>] [--api-key <k>]
          notchmind-cli capture <text>
          notchmind-cli list
          notchmind-cli help

        Notes:
          - For OpenAI/Anthropic, pass --api-key or store it in Keychain via the app.
          - For Ollama, start `ollama serve` and use --provider ollama (default).
        """)
    }

    enum CleanError: Error, LocalizedError {
        case message(String)
        var errorDescription: String? {
            if case .message(let s) = self { return s }
            return nil
        }
    }
}
