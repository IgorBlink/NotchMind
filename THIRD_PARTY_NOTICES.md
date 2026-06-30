# THIRD_PARTY_NOTICES

NotchMind is MIT-licensed. This file attributes the third-party work we
**depend on**, **reference**, or **derive patterns from**. No GPL code is
included in this repository.

## Dependencies (linked at build time)

### sindresorhus/KeyboardShortcuts
- **URL:** https://github.com/sindresorhus/KeyboardShortcuts
- **License:** MIT
- **Use:** Global hotkey registration + user-customizable recorder for the
  Explain (⌥⌘E) and Capture (⌥⌘C) shortcuts. Linked via Swift Package
  Manager.
- **Copyright:** Copyright (c) Sindre Sorhus (https://sindresorhus.com)

### apple/swift-argument-parser
- **URL:** https://github.com/apple/swift-argument-parser
- **License:** Apache-2.0
- **Use:** CLI argument parsing for the `notchmind-cli` SPM executable
  (headless build path only — not in the shipped app).
- **Copyright:** Copyright (c) 2019-2021 Apple Inc.

## Architectural references (no code copied)

The following projects were **studied for architecture and UX patterns**.
Their code is **not** included in this repository. Where a pattern was
adopted, the implementation was written from scratch under NotchMind's MIT
license.

### TheBoredTeam/boring.notch
- **URL:** https://github.com/TheBoredTeam/boring.notch
- **License:** GPL-3.0
- **What we learned:** The canonical "notch as a surface" architecture on
  macOS — `NSPanel` (borderless, `.floating`, non-activating) anchored to
  `NSScreen.safeAreaInsets.top`, hover-to-expand interaction, vibrancy +
  continuous-corner visual language. **No code copied** (GPL-3.0 is viral
  and would relicense this MIT project).

### MrKai77/DynamicNotchKit
- **URL:** https://github.com/MrKai77/DynamicNotchKit
- **License:** MIT (per Swift Package Index; verify at integration time)
- **What we learned:** How to compute the notch rect from
  `auxiliaryTopLeftArea` + `auxiliaryTopRightArea`, and the
  floating-pill fallback for non-notched Macs. We implement our own
  `NotchPanelController` + `NotchGeometry` per the spec; DynamicNotchKit
  remains a candidate dependency if we later prefer to delegate notch UX.

### jackson-storm/DynamicNotch
- **URL:** https://github.com/jackson-storm/DynamicNotch
- **License:** Not stated in README (no code copied regardless)
- **What we learned:** The `NotchEngine` pattern — a queue-driven
  presentation state machine that serializes live activities, temporary
  alerts, and restore flows. Our `NotchViewModel` adopts the same
  single-owner-state-machine idea, written from scratch.

### 0xfullex/selection-hook
- **URL:** https://github.com/0xfullex/selection-hook
- **License:** MIT
- **What we learned:** The clipboard-fallback **policy contract**: AX
  primary, simulated ⌘C only as a last resort, clipboard saved and restored
  around the copy, and a user-facing toggle to disable fallback entirely.
  Mirrored in `SelectionReader` + `ClipboardGuard`.

### democb/swift-enchanted
- **URL:** https://github.com/democb/swift-enchanted
  (specifically `Enchanted/Helpers/Accessibility.swift`)
- **License:** MIT
- **What we learned:** A clean Swift formulation of the AX selected-text
  recipe (`AXUIElementCreateSystemWide` → `kAXFocusedUIElementAttribute` →
  `kAXSelectedTextAttribute`). Our `SelectionReader` follows the same
  recipe, written from scratch.

### Zach Waugh — "Streaming messages from ChatGPT using Swift AsyncSequence"
- **URL:** https://zachwaugh.com/posts/streaming-messages-chatgpt-swift-asyncsequence
- **License:** Blog post (CC-by-default)
- **What we learned:** The canonical `URLSession.bytes(for:)` + `bytes.lines`
  + `data:` prefix + `[DONE]` sentinel recipe for SSE streaming. Our
  `OpenAIClient` and `SSEParser` follow this pattern.

### rotecodefraktion — "The Swift client" / "Streaming" blog series
- **URLs:**
  - https://www.rotecodefraktion.de/en/blog/apfel-agent-03-swift-client/
  - https://www.rotecodefraktion.de/en/blog/hummingbird-04-streaming/
- **License:** Blog posts
- **What we learned:** Wrapping `URLSession.bytes` in an
  `AsyncThrowingStream` with `onTermination` cancellation, and the
  per-provider chunk-shape handling (first chunk carries `role`, subsequent
  chunks carry `content`). Our `LLMClient` protocol + concrete clients
  adopt this shape.

### mattt/ollama-swift
- **URL:** https://github.com/mattt/ollama-swift
- **License:** MIT
- **What we learned:** Ollama's HTTP API shape (`/api/chat`, NDJSON not SSE,
  `done: true` sentinel, localhost only). Our `OllamaClient` implements the
  same API directly rather than depending on the package; we may swap to it
  if Ollama's API grows more complex.

### NotchNook, Notchmeister, MediaMate (closed-source)
- **URLs:** https://lo.cafe/notchnook , https://www.stclairsoft.com/Notchmeister/
- **License:** Commercial / closed-source
- **What we learned:** UX language only — the "don't draw a fake notch on
  non-notched displays" critique from MacStories directly informed our
  floating-pill fallback on non-notched Macs.

## Apple frameworks

NotchMind uses only **public** Apple frameworks and APIs:

- `AppKit` — `NSPanel`, `NSStatusBar`/`MenuBarExtra`, `NSPasteboard`,
  `NSWorkspace`, `NSEvent`, `NSScreen` (`safeAreaInsets`,
  `auxiliaryTopLeftArea`, `auxiliaryTopRightArea`), `NSHostingController`.
- `ApplicationServices` — `AXUIElement`, `AXIsProcessTrustedWithOptions`,
  `kAXSelectedTextAttribute` etc.
- `CoreGraphics` — `CGEvent` for the clipboard-fallback simulated ⌘C.
- `Security` — `SecItem` for Keychain API-key storage.
- `SwiftUI` — notch surface, settings, onboarding, menu-bar dropdown.
- `Foundation` — `URLSession.bytes(for:)`, file I/O, dates.

No private/SPI frameworks (`SkyLight`, `MediaRemote`, `DockKit`-private) are
used. This keeps the app notarization- and App Store-eligible (modulo the
sandbox trade-offs documented in `ENTITLEMENTS.md`).

## Updating this file

When adding a dependency, append a new section under **Dependencies** with
the package URL, license, and a one-line description of what we use. When
adopting a pattern from a blog or repo without copying code, append to
**Architectural references**. **Never** paste GPL-licensed code into this
repository — study it, then reimplement.
