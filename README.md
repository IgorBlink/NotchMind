# NotchMind

> A native macOS menu-bar + notch utility that streams AI explanations of any
> selected text into the MacBook notch, and captures snippets to a portable
> Markdown inbox. Pure Swift. No Electron. No web views.

## What it does

| Hotkey (default) | Action |
|---|---|
| **⌥⌘E** — Explain | Reads the currently-selected text anywhere on macOS, gathers source context (frontmost app, window title, browser URL), streams an AI explanation into the notch token-by-token, and collapses when dismissed. |
| **⌥⌘C** — Capture | Saves the selection to `~/NotchMind/captures/YYYY-MM/…md` as Markdown with YAML frontmatter (source app, window title, URL, timestamp, optional AI summary). Flashes a confirmation toast in the notch. Obsidian-friendly. |

Both hotkeys are user-customizable in **Settings → Hotkeys**.

## Why it's native

- The notch surface is a borderless, non-activating `NSPanel` at
  `.floating` level, positioned over the hardware notch using
  `NSScreen.safeAreaInsets.top` + `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`.
  On non-notched Macs it falls back to a top-center floating pill.
- Selection is read via the **Accessibility API** (`AXSelectedTextAttribute`)
  first, with an opt-in **clipboard-with-restore fallback** so your clipboard
  is never silently clobbered.
- LLM tokens stream over `URLSession.bytes(for:)` parsing SSE (OpenAI,
  Anthropic) or NDJSON (Ollama). See `Sources/NotchMind/LLM/`.
- Hotkeys use `sindresorhus/KeyboardShortcuts` (MIT) — the de-facto standard,
  sandbox-safe, Mac App Store compatible.
- No GPL code is copied. `boring.notch` and `Atoll` are studied for
  architecture only. See `RESEARCH.md` and `THIRD_PARTY_NOTICES.md`.

## Permissions

NotchMind needs **Accessibility** to read selected text without disturbing
your clipboard. On first launch it will prompt you; click **Open System
Settings → Privacy & Security → Accessibility** and toggle NotchMind on.

If you use the **Capture** hotkey on a browser, macOS will also prompt for
**Automation** permission so NotchMind can read the frontmost tab's URL via
AppleScript. This is per-browser (Safari, Chrome, Arc, Brave, Edge, Vivaldi).

See `ENTITLEMENTS.md` for the full TCC matrix and the sandbox migration path.

## Build & run

See `BUILD.md` — the one-command path is:

```bash
xcodegen generate && open NotchMind.xcodeproj
```

Then press ⌘R in Xcode. Or, from the CLI:

```bash
swift run notchmind-cli explain "zeitgeist" --provider ollama
```

## Project layout

```
Sources/NotchMind/
├── App/            # @main, AppDelegate, AppState orchestrator
├── Hotkeys/        # KeyboardShortcuts wrapper
├── Selection/      # AX reader + clipboard-with-restore fallback
├── Context/        # frontmost app, window title, browser URL
├── LLM/            # LLMClient protocol + OpenAI/Anthropic/Ollama + SSE parser
├── Notch/          # NotchPanelController, geometry, state machine
├── Capture/        # Markdown capture store + JSON index
├── Settings/       # UserDefaults + Keychain + provider config
└── UI/             # SwiftUI: notch surface, settings, onboarding, menu bar
Sources/NotchMindCLI/   # headless CLI for `swift run` (LLM + capture exercise)
Resources/          # Info.plist, Assets.xcassets
Supporting/         # NotchMind.entitlements
```

## Configuration

- **LLM provider + model + API key** — Settings → LLM. Keys live in Keychain.
- **Hotkeys** — Settings → Hotkeys (uses `KeyboardShortcuts.Recorder`).
- **Prompt template** — Settings → LLM. Placeholders: `{text}`, `{context}`.
- **Capture folder** — Settings → Capture (default `~/NotchMind/captures`).
- **Notch behavior** — Settings → Notch: font size, max expanded height,
  auto-dismiss timeout, stream-vs-batch toggle.

## Status

This is the initial scaffold: all modules compile and wire together; the
explain/capture flows are end-to-end functional. Known rough edges tracked in
`RESEARCH.md` "Open questions" and in TODO comments where present.

## License

MIT — see `LICENSE`. Third-party attributions in `THIRD_PARTY_NOTICES.md`.
