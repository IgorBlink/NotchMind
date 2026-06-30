import AppKit
import Foundation

/// Reads the frontmost browser's active tab URL via AppleScript.
///
/// Supported: Safari, Google Chrome, Arc, Brave, Edge, Vivaldi, Orion.
/// Each browser exposes a slightly different AppleScript dictionary; we keep
/// one small handler per family.
///
/// Requires the `NSAppleEventsUsageDescription` Info.plist key and the
/// `com.apple.security.automation.apple-events` entitlement (both set). The
/// first call triggers the standard macOS "wants to control <Browser>" prompt.
public enum BrowserURLReader {

    /// Map of bundle IDs → AppleScript family. Keep alphabetical for readability.
    private static let families: [String: Family] = [
        "com.apple.Safari":          .safari,
        "com.google.Chrome":         .chromium,
        "company.thebrowser.Browser": .chromium,  // Arc
        "com.brave.Browser":         .chromium,
        "com.microsoft.edgemac":     .chromium,
        "com.vivaldi.Vivaldi":       .chromium,
        "com.kagi.kagi":             .chromium,
        "com.orion.Orion":           .safari
    ]

    private enum Family {
        case safari
        case chromium
    }

    /// Returns the frontmost browser's active tab URL, or `nil` if the
    /// frontmost app isn't a known browser or the call fails.
    @MainActor
    public static func url(forFrontmostBundleID bundleID: String?) -> String? {
        guard let bundleID, let family = families[bundleID] else { return nil }
        switch family {
        case .safari:
            return run(script: Self.safariScript)
        case .chromium:
            return run(script: Self.chromiumScript)
        }
    }

    // MARK: - Scripts
    //
    // Scripts are intentionally tiny and read-only. They return the URL of
    // the active tab of the frontmost window. We don't touch titles here —
    // the window title comes from AX in `ContextGatherer`.

    private static let safariScript = """
    tell application "Safari"
        if (count of windows) = 0 then return ""
        return URL of document 1 of window 1
    end tell
    """

    private static let chromiumScript = """
    tell application "Google Chrome"
        if (count of windows) = 0 then return ""
        return URL of active tab of window 1
    end tell
    """

    @MainActor
    private static func run(script: String) -> String? {
        let appleScript = NSAppleScript(source: script)
        var errorInfo: NSDictionary?
        let output = appleScript?.executeAndReturnError(&errorInfo)
        if let errorInfo {
            // Common: user denied automation permission (-1743). We silently
            // fall through; the caller treats nil as "no URL available".
            _ = errorInfo
            return nil
        }
        let value = output?.stringValue ?? ""
        return value.isEmpty ? nil : value
    }
}
