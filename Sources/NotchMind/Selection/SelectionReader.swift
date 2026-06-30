import AppKit
import ApplicationServices
import Foundation

/// Reads the currently-selected text from the frontmost app.
///
/// Strategy:
/// 1. **AX primary** — `AXUIElementCreateSystemWide()` →
///    `kAXFocusedUIElementAttribute` → `kAXSelectedTextAttribute`. This is
///    the only path that doesn't disturb the clipboard.
/// 2. **Clipboard fallback** — when AX fails (permission denied, app doesn't
///    expose AX selected text, or the AX call returns `.cannotComplete`),
///    simulate ⌘C and read the pasteboard, then restore the prior contents.
///    Only used when `SettingsStore.allowClipboardFallback` is true.
///
/// The result tells the caller which path was used so the notch can surface
/// "used clipboard" honestly.
public struct SelectionResult: Sendable, Equatable {
    public let text: String
    public let source: Source
    public enum Source: Sendable, Equatable {
        case accessibility
        case clipboardFallback
    }
    public init(text: String, source: Source) {
        self.text = text
        self.source = source
    }
}

public enum SelectionReader {

    /// Check whether the app has been granted Accessibility permission.
    public static func isAccessibilityEnabled() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Prompt the user to grant Accessibility permission (opens System Settings
    /// on macOS 13+ via the deep-link URL).
    public static func promptAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Read selected text. AX first; clipboard fallback when allowed.
    @MainActor
    public static func readSelectedText(
        allowClipboardFallback: Bool,
        fallbackDelay: UInt32 = 80_000
    ) -> SelectionResult? {
        if let text = readViaAccessibility(), !text.isEmpty {
            return SelectionResult(text: text, source: .accessibility)
        }
        guard allowClipboardFallback else { return nil }
        if let text = readViaSimulatedCopy(fallbackDelay: fallbackDelay), !text.isEmpty {
            return SelectionResult(text: text, source: .clipboardFallback)
        }
        return nil
    }

    /// Direct AX read. Returns `nil` on any failure (no permission, no focused
    /// text element, empty selection, etc.).
    private static func readViaAccessibility() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusedErr = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        guard focusedErr == .success, let focused = focusedRef else { return nil }
        let element = focused as! AXUIElement

        var selectedRef: CFTypeRef?
        let selectedErr = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedRef
        )
        guard selectedErr == .success, let value = selectedRef else { return nil }
        return value as? String
    }

    /// Simulate ⌘C, read pasteboard, restore. The `fallbackDelay` gives the
    /// frontmost app a moment to service the copy event before we read.
    @MainActor
    private static func readViaSimulatedCopy(fallbackDelay: UInt32) -> String? {
        let snapshot = ClipboardGuard.snapshot()
        NSPasteboard.general.clearContents()
        ClipboardGuard.simulateCopy()
        usleep(fallbackDelay)
        let result = NSPasteboard.general.string(forType: .string)
        // Always restore, whether or not we got something.
        ClipboardGuard.restore(snapshot)
        return result
    }
}
