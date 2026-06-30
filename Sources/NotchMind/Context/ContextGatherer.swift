import AppKit
import ApplicationServices
import Foundation

/// Builds a `SourceContext` for the frontmost app.
///
/// Order of operations (all best-effort):
/// 1. `NSWorkspace.frontmostApplication` → app name + bundle ID.
/// 2. AX `kAXTitleAttribute` of the focused window → window title.
/// 3. `BrowserURLReader.url(forFrontmostBundleID:)` → URL (browsers only).
public enum ContextGatherer {

    @MainActor
    public static func gather() -> SourceContext {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontApp?.bundleIdentifier
        let appName = frontApp?.localizedName

        let windowTitle = readWindowTitle(frontmostAppPID: frontApp?.processIdentifier)
        let url = BrowserURLReader.url(forFrontmostBundleID: bundleID)

        return SourceContext(
            appName: appName,
            appBundleID: bundleID,
            windowTitle: windowTitle,
            url: url
        )
    }

    /// Walk the frontmost app's AX tree to find the focused window's title.
    /// Many apps expose this on the application element's `kAXMainWindowAttribute`
    /// or `kAXFocusedWindowAttribute`.
    @MainActor
    private static func readWindowTitle(frontmostAppPID pid: pid_t?) -> String? {
        guard let pid else { return nil }
        let appElement = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        // Try focused window first; fall back to main window.
        if AXUIElementCopyAttributeValue(appElement,
                                         kAXFocusedWindowAttribute as CFString,
                                         &windowRef) != .success {
            AXUIElementCopyAttributeValue(appElement,
                                          kAXMainWindowAttribute as CFString,
                                          &windowRef)
        }
        guard let window = windowRef else { return nil }
        let windowElement = window as! AXUIElement
        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowElement,
                                            kAXTitleAttribute as CFString,
                                            &titleRef) == .success,
              let title = titleRef as? String else { return nil }
        return title
    }
}
