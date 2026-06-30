# RESEARCH.md — NotchMind

> Findings from the research phase, performed before any implementation. The
> goal: reuse solved problems (hotkeys, notch geometry, HTTP/SSE) and build
> custom only where the product differs (the explain/capture UX and the
> streaming notch surface).

## Method

Targeted GitHub + web searches across five problem areas:
1. macOS notch utilities in Swift (architecture reference)
2. Global hotkeys in Swift (dependency)
3. Reading selected text without the clipboard (AX API)
4. Obsidian-style capture to Markdown inbox (UX reference)
5. LLM streaming in Swift (HTTP/SSE pattern)

Each candidate was evaluated on **license compatibility** (the project ships
under MIT — see `LICENSE` — so GPL code may be studied but never copied in),
**maintenance signals**, **API surface**, and **fit for the spec**.

---

## 1. macOS notch utilities in Swift

### TheBoredTeam/boring.notch
- **URL:** https://github.com/TheBoredTeam/boring.notch
- **License:** GPL-3.0
- **Stars:** ~8k, active (latest release v2.7.3, Nov 2025)
- **Stack:** Swift, SwiftUI, macOS 14+, Xcode 16+
- **What we take:** **Architecture only.** Boring Notch is the canonical
  reference for "notch as a surface" on macOS. We study:
  - `NSPanel` (borderless, `.floating`, non-activating) anchored to the notch
    using `NSScreen.safeAreaInsets.top` and the screen's
    `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`.
  - The hover-to-expand / click-to-collapse state model.
  - Their HUD-replacement visual language (rounded continuous corners,
    vibrancy, shadow).
- **What we build ourselves:** Everything. **GPL-3.0 is viral — copying any
  code into an MIT project would relicense NotchMind.** We reimplement the
  patterns from scratch and credit them here and in
  `THIRD_PARTY_NOTICES.md`.
- **Verdict:** Reference only. No code copied.

### MrKai77/DynamicNotchKit
- **URL:** https://github.com/MrKai77/DynamicNotchKit
- **License:** MIT (per Swift Package Index; `LICENSE` fetch timed out during
  research — confirm at integration time if we ever depend on it)
- **Stack:** Swift Package, macOS 13+, Swift 6 concurrency-ready
- **API surface:**
  - `DynamicNotch { ContentView }` — present SwiftUI content from the notch.
  - `DynamicNotchInfo` — prebuilt title/description/icon popover.
  - `DynamicNotchProgress` — activity indicator.
  - `.floating` style auto-applies on non-notched Macs (top-center pill).
  - `DynamicNotchTransitionConfiguration` (v0.1+) — custom open/close/convert
    animations, `skipIntermediateHides` for fast state switches.
  - Compact state — side-mounted, mirrors iOS Dynamic Island.
- **Decision:** **Reference, not dependency.** The spec explicitly requires a
  custom `NotchPanelController` over `NSPanel` positioned via
  `safeAreaInsets.top` + `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`, with
  bespoke streaming-token UX and a capture-toast state that DynamicNotchKit's
  prebuilt classes don't model. depending on it would fight the spec. We
  borrow the **geometry approach** (how to compute the notch rect on notched
  vs non-notched screens) and the **floating fallback** idea, but write our
  own `NotchPanelController` + `NotchView`. If the user later prefers the
  dependency, the `Notch/` layer is the only thing that needs to change.
- **Verdict:** Architectural reference. Not a dependency (yet).

### jackson-storm/DynamicNotch
- **URL:** https://github.com/jackson-storm/DynamicNotch
- **License:** Not stated in README (verify before any reuse)
- **Stack:** Swift, SwiftUI + AppKit, Combine, Lottie
- **What we take:** **The `NotchEngine` idea** — a queue-driven presentation
  state machine that serializes live activities, temporary alerts, and
  restore flows. We adopt the same separation in `NotchViewModel`: a
  single-owner state machine that decides what the notch shows, so a
  streaming explanation and a capture toast don't fight for the surface.
- **What we build ourselves:** The actual engine. No code copied.
- **Verdict:** Pattern reference only.

### Ebullioscopic/Atoll
- **URL:** https://github.com/Ebullioscopic/Atoll
- **License:** Inherited from boring.notch (GPL-3.0)
- **Notes:** Self-described fork/derivative of boring.notch. Same GPL
  constraint — reference only.
- **Verdict:** Reference only.

### NotchNook (lo.cafe), Notchmeister (St. Clair Software), MediaMate
- **URLs:** https://lo.cafe/notchnook , https://www.stclairsoft.com/Notchmeister/ ,
  https://www.macstories.net/reviews/notchnook-and-mediamate-...
- **License:** Commercial / closed-source
- **What we take:** **UX language only.** NotchNook's "Tray + AirDrop" model
  and MacStories' critique ("don't draw a fake notch on non-notched
  displays") directly inform our **floating-pill fallback** on non-notched
  Macs. Notchmeister's glow/radar effects are out of scope.
- **Verdict:** UX reference only.

### 0xfullex/selection-hook
- **URL:** https://github.com/0xfullex/selection-hook
- **License:** MIT (Node.js/Electron addon — not Swift-reusable)
- **What we take:** **The clipboard-fallback contract.** Their docs articulate
  the exact policy we adopt: AX primary, simulated ⌘C only as a last resort,
  clipboard contents saved and restored around the simulated copy, and a
  user-facing toggle to disable clipboard fallback entirely. We mirror this
  in `SelectionReader` + `ClipboardGuard`.
- **Verdict:** Policy reference. Not a dependency (different language).

---

## 2. Global hotkeys in Swift

### sindresorhus/KeyboardShortcuts
- **URL:** https://github.com/sindresorhus/KeyboardShortcuts
- **License:** MIT (do-whatever, compatible)
- **Stack:** Swift Package, sandboxed, Mac App Store compatible
- **Production use:** Dato, Jiffy, Plash, Lungo (all by sindresorhus)
- **API surface we use:**
  - `extension KeyboardShortcuts.Name { static let explain = Self("explain", default: .init(.e, modifiers: [.option, .command])) }`
  - `KeyboardShortcuts.onKeyUp(for: .explain) { ... }` — global listener.
  - `KeyboardShortcuts.Recorder(for: .explain)` — SwiftUI recorder for
    Settings; handles conflict warnings and persists to `UserDefaults`.
  - Works while an `NSMenu` is open (critical for menu-bar apps).
- **Decision:** **Primary dependency.** This is the de-facto standard,
  sandbox-safe, handles Carbon `RegisterEventHotKey` plumbing, conflict
  detection, and per-user customization. Reimplementing this would be pure
  NIH. We wrap it in `HotkeyManager` so the rest of the app never touches
  the package directly.
- **Verdict:** **Depend on it.**

---

## 3. Reading selected text without the clipboard

### The pattern (cross-references)
- Stack Overflow: https://stackoverflow.com/questions/1487175/ + /76009610/
- Working Swift example: https://github.com/democb/swift-enchanted/blob/main/Enchanted/Helpers/Accessibility.swift
- Insert-text counterpart (confirms attribute semantics):
  https://levelup.gitconnected.com/swift-macos-insert-text-to-other-active-applications-two-ways-...

### The recipe we adopt
```swift
let systemWide = AXUIElementCreateSystemWide()
var focused: CFTypeRef?
AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
guard let element = focused as? AXUIElement else { return nil }
var value: CFTypeRef?
AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
return value as? String
```

### Fallback (clipboard with restore)
When AX returns `nil` or `.cannotComplete` (e.g. accessibility not granted,
or the focused app doesn't expose `kAXSelectedTextAttribute`):
1. Snapshot `NSPasteboard.general` contents.
2. Clear pasteboard.
3. Simulate ⌘C via `CGEvent` (keyDown + keyUp with `flagsMask = .maskCommand`).
4. Read `pasteboard.string(forType: .string)`.
5. Restore the snapshot (re-`clearContents`, re-`setString` for each item).
6. Surface a "used clipboard" notice in the notch so the user knows.

### Sandbox caveat
SO answers note simulated ⌘C "only works if you turn off App Sandbox"
(can't submit to Mac App Store). This is one reason NotchMind ships
**non-sandboxed** initially (see `ENTITLEMENTS.md`). The AX path itself is
sandbox-compatible; only the clipboard fallback needs the sandbox off.

### Decision
Build `SelectionReader` + `ClipboardGuard` in-house. No third-party
dependency — the pattern is ~80 lines and we need tight control over the
restore semantics. The `swift-enchanted` Accessibility.swift is the cleanest
reference and is MIT-licensed; we credit it in `THIRD_PARTY_NOTICES.md` even
though we don't copy code verbatim.

- **Verdict:** Build custom. Reference `swift-enchanted` (MIT).

---

## 4. Obsidian-style capture to Markdown inbox

### Obsidian's model (reference, not code)
- Obsidian QuickAdd + "Capture to inbox" plugin pattern: a hotkey that
  appends the current selection (or a prompt) to a chosen Markdown file with
  optional metadata frontmatter and a timestamp.
- The portability insight: **plain `.md` files in a predictable folder** beat
  a proprietary DB because Obsidian / Bear / Logseq can index them directly.

### What we build
- `CaptureStore` writes one file per capture to
  `~/NotchMind/captures/YYYY-MM/YYYY-MM-DD-HHMMSS-slug.md`.
- Each file has YAML frontmatter (`source_app`, `window_title`, `url`,
  `captured_at`, `summary`) and the captured text as the body.
- A sibling `~/NotchMind/index.json` is maintained for fast search in the
  menu-bar popover (the Markdown files remain the source of truth; the index
  is rebuildable).
- Optional one-line AI summary is generated by the same `LLMClient` (non-
  streaming) and stored as `summary` in frontmatter and shown as the preview
  row in the popover.

### Decision
Build custom. No reuse — the Obsidian plugins are TypeScript and the UX is
small enough to nail natively.

- **Verdict:** Build custom.

---

## 5. LLM streaming in Swift

### The pattern (cross-references)
- Apple WWDC21 "Use async/await with URLSession" — `URLSession.bytes(for:)`
  returns `AsyncBytes`; iterate `bytes.lines` for line-buffered SSE.
- Zach Waugh — https://zachwaugh.com/posts/streaming-messages-chatgpt-swift-asyncsequence
  (the canonical short example).
- rotecodefraktion — wraps it in `AsyncThrowingStream<ChatChunk, Error>` with
  an `SSEParser` and `[DONE]` sentinel handling; `onTermination` cancels the
  task.

### The recipe we adopt
```swift
let (bytes, response) = try await session.bytes(for: request)
guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw … }
for try await line in bytes.lines {
    guard line.hasPrefix("data: ") else { continue }
    let payload = line.dropFirst(6)
    if payload == "[DONE]" { break }
    guard let data = payload.data(using: .utf8) else { continue }
    let chunk = try JSONDecoder().decode(StreamChunk.self, from: data)
    yield chunk.delta?.content ?? ""
}
```

### Provider differences
- **OpenAI** (`/v1/chat/completions`, `stream: true`): SSE, `data: {…}`,
  `data: [DONE]`. Delta shape: `{choices:[{delta:{content:"…"}}]}`.
- **Anthropic** (`/v1/messages`, `stream: true`): SSE with named event types
  — `event: content_block_delta` / `data: {…delta{…text}}`. Requires
  `anthropic-version` and `anthropic-beta` headers. Different parse path.
- **Ollama** (`/api/chat`, `stream: true`): **NDJSON, not SSE** — one JSON
  object per line, no `data:` prefix, final `{"done":true,…}` sentinel.
  Localhost only; no API key.

### Candidate SDKs (considered, not adopted)
- **mattt/ollama-swift** — MIT, NSHipster-endorsed, macOS 13+, supports
  structured outputs + tools. Clean API. Would save ~60 lines for the
  Ollama path but adds a dependency that doesn't help OpenAI/Anthropic.
- **kevinhermawan/OllamaKit** — MIT, powers Ollamac. Same trade-off.
- **OpenAI SDKs** — several community ones; none canonical, all carry
  baggage we don't need (function-calling scaffolding, etc.).

### Decision
Build a thin `LLMClient` protocol with three implementations
(`OpenAIClient`, `AnthropicClient`, `OllamaClient`) sharing one
`SSEParser` (and an `NDJSONParser` for Ollama). Each is ~100 lines. This
matches the spec ("`LLMClient` — protocol with … implementations; streaming
via `URLSession.bytes(for:)`") and keeps provider quirks isolated. If
Ollama's API grows more complex we can swap `OllamaClient`'s guts to
`mattt/ollama-swift` without touching the protocol.

- **Verdict:** Build custom. Reference `mattt/ollama-swift` (MIT) if Ollama
  grows. Credit Zach Waugh + rotecodefraktion in
  `THIRD_PARTY_NOTICES.md` for the SSE pattern.

---

## Reuse plan — summary table

| Problem | Reuse | License | Decision |
|---|---|---|---|
| Global hotkeys | `sindresorhus/KeyboardShortcuts` | MIT | **Depend (SPM)** |
| Notch geometry & UX | `MrKai77/DynamicNotchKit` | MIT* | Reference; build custom |
| Notch architecture | `TheBoredTeam/boring.notch` | GPL-3.0 | **Reference only — no code** |
| Notch state machine | `jackson-storm/DynamicNotch` | unclear | Pattern reference only |
| AX selected text | `democb/swift-enchanted` | MIT | Pattern reference; build custom |
| Clipboard fallback policy | `0xfullex/selection-hook` | MIT | Policy reference |
| SSE streaming pattern | Zach Waugh, rotecodefraktion | CC-BY / blog | Pattern reference; build custom |
| Ollama client | `mattt/ollama-swift` | MIT | Build custom; swap later if needed |
| Obsidian capture UX | Obsidian QuickAdd (TS) | — | UX reference; build custom |
| Non-notched fallback UX | NotchNook (closed) | — | UX reference |

\* Verify `DynamicNotchKit` LICENSE at integration time if we ever depend on it.

## Dependency list (final)

- `sindresorhus/KeyboardShortcuts` ≥ 2.0.0 (SPM) — the only third-party
  runtime dependency.

Everything else is implemented in `Sources/NotchMind/` under MIT.

## What we explicitly do NOT do

- **No GPL code in the tree.** `boring.notch` and `Atoll` are studied for
  architecture and never copied. This keeps NotchMind's MIT license valid.
- **No private/SPI APIs.** `SkyLight`, `MediaRemote`, and other private
  frameworks used by some notch apps are off-limits — they break App Store
  and notarization. We use only `AppKit` + `ApplicationServices` + `ScreenSaver`
  public APIs (`NSScreen.safeAreaInsets`, `auxiliaryTopLeftArea`,
  `auxiliaryTopRightArea`, `AXUIElement…`).
- **No hardcoded API keys.** Provider keys live in Keychain (see
  `Settings/KeychainStore.swift`).
- **No Electron / WebView for the notch.** Pure SwiftUI + NSPanel.

## Open questions (resolve during milestone work)

1. **DynamicNotchKit as a dependency?** Deferred. If our hand-rolled
   `NotchPanelController` ends up reinventing its `DynamicNotchStyle` +
   transition config, reconsider to save code.
2. **Ollama SDK adoption?** Deferred. The NDJSON parse is trivial today.
3. **Sandboxing for App Store?** Deferred to a post-launch milestone. AX
   works sandboxed; clipboard fallback + Apple Events need entitlements.
   Tracked in `ENTITLEMENTS.md`.
