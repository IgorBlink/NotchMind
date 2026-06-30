# ENTITLEMENTS.md

NotchMind ships as a **non-sandboxed, notarized** macOS utility. This is a
deliberate choice: the Accessibility-API path is sandbox-compatible, but the
clipboard-fallback path and the Apple-Events path to browsers are not (or
require per-app temporary exceptions that App Review rejects).

## Current entitlements (`Supporting/NotchMind.entitlements`)

| Key | Value | Why |
|---|---|---|
| `com.apple.security.app-sandbox` | `false` | AX clipboard fallback + Apple Events to arbitrary browsers need this. |
| `com.apple.security.automation.apple-events` | `true` | Send AppleScript to Safari/Chrome/Arc/Brave/Edge/Vivaldi for URL context. |
| `com.apple.security.network.client` | `true` | Reach OpenAI / Anthropic / localhost Ollama. |
| `com.apple.security.files.user-selected.read-write` | `true` | Future: let user pick a custom capture folder via NSOpenPanel. |
| `com.apple.security.cs.allow-jit` | `false` | Not needed; hardened runtime stays strict. |
| `com.apple.security.cs.allow-unsigned-executable-memory` | `false` | Not needed. |
| `com.apple.security.cs.disable-library-validation` | `false` | Not needed — only loads system + signed Swift runtime. |

## TCC permissions (runtime, not entitlements)

| Permission | When prompted | Used by |
|---|---|---|
| **Accessibility** | First hotkey press (or onboarding) | `SelectionReader` AX path. Without it, falls back to clipboard-with-restore. |
| **Automation** (per-browser) | First capture/explain on a browser | `BrowserURLReader` AppleScript for URL context. Each browser prompts separately. |

No **Screen Recording**, **Camera**, **Microphone**, **Contacts**, **Full
Disk Access**, or **Location** is requested or used.

## Sandbox migration path (App Store, future)

To ship on the App Store, flip `app-sandbox` to `true` and accept these
trade-offs:

1. **Clipboard fallback is disabled.** The simulated ⌘C path requires
   `com.apple.security.temporary-exception.apple-events` for
   `com.apple.systemevents`, which App Review rejects. The AX-only path
   still works; apps that don't expose `kAXSelectedTextAttribute` simply
   won't be supported. Surface this honestly in the notch.
2. **Apple Events to browsers** require listing each bundle ID under
   `com.apple.security.temporary-exception.apple-events` (or the modern
   `com.apple.declaration.automation.apple-events` declaration if/when
   supported). Each browser must be opted in explicitly.
3. **Capture folder** must move from `~/NotchMind/captures/` to the app's
   App-Sandbox-Container Documents folder, or use a user-selected folder via
   `NSOpenPanel` + security-scoped bookmarks. The Markdown files remain
   user-accessible either way.

These are tracked as a post-launch milestone; the current non-sandboxed build
is the right starting point for a utility that needs to read selections
across every app on the system.
