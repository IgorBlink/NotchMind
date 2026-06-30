# ENTITLEMENTS.md

NotchMind ships as a **non-sandboxed, notarized** macOS utility. This is a
deliberate choice: the Accessibility-API path is sandbox-compatible, but the
clipboard-fallback path and the Apple-Events path to browsers are not (or
require per-app temporary exceptions that App Review rejects).

## Current entitlements (`Supporting/NotchMind.entitlements`)

The shipping file is intentionally minimal — with the sandbox off, none of the
`com.apple.security.*` TCC entitlements are required. Apple Events, network,
and file access are governed by **runtime TCC prompts** instead of entitlements.

| Key | Value | Why |
|---|---|---|
| `com.apple.security.app-sandbox` | `false` | AX clipboard fallback + Apple Events to arbitrary browsers need this. |

That's it. The hardened-runtime flags (`cs.allow-jit`, `cs.allow-unsigned-executable-memory`,
`cs.disable-library-validation`) are left **unset** for local debug builds so
ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`) works without friction. The
notarization milestone flips `ENABLE_HARDENED_RUNTIME = YES` and re-adds the
hardened-runtime keys (all `false`) — see "Notarization" below.

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
