# BUILD.md

## Prerequisites

- macOS 13.0+ (14+ recommended for the cleanest notch APIs)
- Xcode 15+ (project was generated with Xcode 26 / Swift 6.3)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) — install once:
  ```bash
  brew install xcodegen
  ```

## One-command build & run

```bash
xcodegen generate && open NotchMind.xcodeproj
```

Then press **⌘R** in Xcode to build and launch. The app runs as a
menu-bar-only agent (no Dock icon) — look for the brain icon in the menu bar.

## First run

1. The **Accessibility** prompt appears on first hotkey press. Click **Open
   System Settings**, toggle NotchMind on under
   **Privacy & Security → Accessibility**, then press ⌥⌘E again.
2. Open the menu-bar item → **Settings → LLM**, pick a provider, and add
   your API key (stored in Keychain). For **Ollama**, just run
   `ollama pull llama3.2` and leave the key blank.
3. Select any text in any app and press **⌥⌘E** to stream an explanation
   into the notch, or **⌥⌘C** to capture it to `~/NotchMind/captures/`.

## Headless CLI (no Xcode)

For fast type-checking and to exercise the LLM/capture paths from the
terminal:

```bash
swift build                                    # type-check the core library
swift run notchmind-cli explain "zeitgeist" --provider ollama
swift run notchmind-cli explain "zeitgeist" --provider openai --api-key sk-...
swift run notchmind-cli capture "a snippet to remember"
swift run notchmind-cli list
```

## Build verification

```bash
xcrun swift build                              # SPM core + CLI
xcodegen generate && xcodebuild -project NotchMind.xcodeproj -scheme NotchMind build
```

## Packaging (notarization-ready)

Not yet wired. The entitlements (`Supporting/NotchMind.entitlements`) are
already notarization-safe (hardened runtime, no JIT, no unsigned memory).
To notarize:

```bash
xcodebuild -project NotchMind.xcodeproj -scheme NotchMind archive \
  -archivePath build/NotchMind.xcarchive
xcodebuild -exportArchive -archivePath build/NotchMind.xcarchive \
  -exportOptionsPlist Supporting/ExportOptions.plist \
  -exportPath build/export
```

`Supporting/ExportOptions.plist` and the notarization script are tracked as
a follow-up milestone.
