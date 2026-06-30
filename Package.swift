// swift-tools-version: 5.9
// NotchMind — macOS notch utility for AI text explanation.
//
// This Package.swift exists so contributors can run `swift build` / `swift run`
// against the same Swift sources that the Xcode project compiles. The shipping
// app is built via the xcodegen-managed `NotchMind.xcodeproj` (see BUILD.md)
// because an .app bundle with Info.plist + entitlements needs an Xcode target.
//
// The SPM executable target below is a headless build path: it links the core
// sources (everything except the @main app entry) plus KeyboardShortcuts and
// produces a CLI for exercising the LLM/capture paths. Arg parsing is done by
// hand to keep the dependency surface minimal.

import PackageDescription

let package = Package(
    name: "NotchMind",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "notchmind-cli", targets: ["NotchMindCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "NotchMindCore",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/NotchMind",
            exclude: [
                "App/NotchMindApp.swift",
                "App/AppDelegate.swift"
            ]
        ),
        .executableTarget(
            name: "NotchMindCLI",
            dependencies: ["NotchMindCore"],
            path: "Sources/NotchMindCLI"
        )
    ]
)
