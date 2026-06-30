import AppKit
import Foundation

/// Geometry of the notch (or floating-pill fallback) on the current screen.
///
/// On notched Macs we use `NSScreen.safeAreaInsets.top` for the notch height
/// and derive the notch width from `auxiliaryTopLeftArea` +
/// `auxiliaryTopRightArea` (the "usable menu bar" rects on either side).
/// On non-notched Macs both auxiliary areas are `nil`; we fall back to a
/// top-center floating pill so the app is still useful.
///
/// `panelFrame` is the rect the `NSPanel` should occupy to cover the notch
/// AND have room to expand downward. Width is the notch width with padding;
/// height starts at the notch height and grows with the expanded content.
public struct NotchGeometry: Sendable, Equatable {

    public let screen: NSScreen
    public let hasNotch: Bool
    public let notchWidth: CGFloat
    public let notchHeight: CGFloat
    /// Top-left corner + size of the panel in **window** coordinates (origin
    /// top-left of the screen). `NotchPanelController` converts these to
    /// NSScreen coordinates when calling `setFrame`.
    public let panelOrigin: CGPoint
    public let panelSize: CGSize

    /// Default expanded width/height padding around the notch. Tunable.
    public static let expandedWidthPadding: CGFloat = 32
    public static let collapsedHeightPadding: CGFloat = 0
    public static let nonNotchedPillWidth: CGFloat = 240
    public static let nonNotchedPillHeight: CGFloat = 28

    public static func current(expandedHeight: CGFloat) -> NotchGeometry? {
        // Prefer the screen that currently has the key window, falling back to
        // the main screen. This keeps the notch on the active display.
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation()) }
            ?? NSScreen.main
        guard let screen else { return nil }
        return Self(for: screen, expandedHeight: expandedHeight)
    }

    public init(for screen: NSScreen, expandedHeight: CGFloat) {
        self.screen = screen
        let safeTop = screen.safeAreaInsets.top
        let hasNotch = safeTop > 0 && screen.auxiliaryTopLeftArea != nil

        if hasNotch, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            // Auxiliary areas are in the same coordinate space as `frame`:
            // origin bottom-left, y increasing upward. The notch is the gap
            // between left.maxX and right.minX at the very top of the screen.
            let notchMinX = left.maxX
            let notchMaxX = right.minX
            self.notchWidth = max(notchMaxX - notchMinX, 0)
            self.notchHeight = safeTop
            self.hasNotch = true
        } else {
            self.notchWidth = Self.nonNotchedPillWidth
            self.notchHeight = Self.nonNotchedPillHeight
            self.hasNotch = false
        }

        // The panel is centered on the notch horizontally and aligned to the
        // very top of the screen. It grows downward by `expandedHeight`.
        let panelWidth = self.notchWidth + Self.expandedWidthPadding * (hasNotch ? 1 : 0)
        let panelHeight = max(self.notchHeight, expandedHeight)
        let panelX = screen.frame.midX - panelWidth / 2
        // Window-coordinate origin (top-left of screen) — converted to
        // NSScreen coordinates by the panel controller.
        let panelY: CGFloat = 0
        self.panelOrigin = CGPoint(x: panelX, y: panelY)
        self.panelSize = CGSize(width: panelWidth, height: panelHeight)
    }

    /// Convert the window-coordinate panel rect to NSScreen coordinates
    /// (origin bottom-left of the primary screen, y up).
    public func panelFrameInScreenCoordinates() -> CGRect {
        let screenTop = screen.frame.maxY
        return CGRect(
            x: panelOrigin.x,
            y: screenTop - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    /// Where the notch "lips" are — the visible rounded shape that hugs the
    /// hardware notch. In window-local coordinates (origin top-left of the
    /// panel). Used by `NotchView` to draw the collapsed pill.
    public func notchRectInPanelSpace() -> CGRect {
        let x = (panelSize.width - notchWidth) / 2
        return CGRect(x: x, y: 0, width: notchWidth, height: notchHeight)
    }

    private static func mouseLocation() -> CGPoint {
        NSEvent.mouseLocation
    }
}
