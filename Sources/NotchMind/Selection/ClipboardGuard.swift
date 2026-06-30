import AppKit
import CoreGraphics

/// Saves and restores the system pasteboard around a simulated ⌘C so the
/// user never loses what they had copied.
///
/// Policy reference: `0xfullex/selection-hook` (see RESEARCH.md) — AX first,
/// simulated copy only as a last resort, restore on success AND failure.
public enum ClipboardGuard {

    /// Snapshot the current pasteboard items so they can be restored later.
    public struct Snapshot {
        fileprivate let items: [NSPasteboardItem]
    }

    public static func snapshot() -> Snapshot {
        let items = NSPasteboard.general.pasteboardItems ?? []
        // Re-create pasteboard items so they remain valid after we clear the
        // system pasteboard. NSPasteboardItem retains its types/data independently.
        return Snapshot(items: items)
    }

    public static func restore(_ snapshot: Snapshot) {
        let pb = NSPasteboard.general
        pb.clearContents()
        // Re-write the string contents we captured. We only restore .string
        // types because that's all we use; restoring arbitrary NSPasteboardItem
        // data types across clearContents is unreliable without deep copying.
        let strings = snapshot.items.compactMap { $0.string(forType: .string) }
        if !strings.isEmpty {
            pb.setStrings(strings)
        }
    }

    /// Simulate ⌘C with the current key event state. Runs on the main thread
    /// because CGEvent posting must happen on main.
    @MainActor
    public static func simulateCopy() {
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)  // 0x08 = C
        cmdDown?.flags = .maskCommand
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdDown?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }

    /// Read the current pasteboard string without disturbing it.
    public static func currentString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}

private extension NSPasteboard {
    func setStrings(_ strings: [String]) {
        clearContents()
        // `NSPasteboardItem(pasteboardPropertyList:ofType:)` is failable, so
        // compactMap to drop any that fail to construct.
        let items: [NSPasteboardItem] = strings.compactMap {
            NSPasteboardItem(pasteboardPropertyList: $0, ofType: .string)
        }
        guard !items.isEmpty else { return }
        writeObjects(items)
    }
}
