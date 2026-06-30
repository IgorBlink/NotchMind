import AppKit
import SwiftUI

/// Owns the borderless `NSPanel` that floats above the menu bar / notch and
/// hosts the SwiftUI `NotchView`.
///
/// Design notes:
/// - `.nonactivating` panel so pressing the hotkey never steals focus from
///   the app the user is reading from.
/// - `.floating` level above `NSStatusBar` so the notch stays visible over
///   the menu bar.
/// - `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`
///   so the notch follows the user across spaces and survives fullscreen.
/// - We recompute geometry on screen-change notifications and on each
///   `show()` so the panel tracks the active display.
@MainActor
public final class NotchPanelController {

    public let viewModel: NotchViewModel

    private var panel: NSPanel?
    private var hostingController: NSHostingController<NotchView>?
    private var screenChangeObserver: NSObjectProtocol?
    private var expandedHeight: CGFloat = 320

    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        observeScreenChanges()
    }

    deinit {
        if let obs = screenChangeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    private func observeScreenChanges() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.repositionIfNeeded()
        }
    }

    /// Show the panel (creating it lazily) and reposition to the current
    /// screen's notch. `expandedHeight` is the max height the panel may grow
    /// to; we set the panel frame to that so SwiftUI can fill it.
    public func show(expandedHeight: CGFloat = 320) {
        self.expandedHeight = expandedHeight
        ensurePanel()
        reposition()
        panel?.orderFrontRegardless()
    }

    public func hide() {
        panel?.orderOut(nil)
    }

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Panel lifecycle

    private func ensurePanel() {
        guard panel == nil else { return }

        let initialFrame = CGRect(x: 0, y: 0, width: 240, height: 32)
        let panel = NotchPanel(contentRect: initialFrame,
                               styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false  // SwiftUI draws its own shadow
        panel.hidesOnDeactivate = false
        panel.worksWhenModal = true
        panel.ignoresMouseEvents = false

        let hosting = NSHostingController(rootView: NotchView(viewModel: viewModel))
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = .clear
        panel.contentViewController = hosting
        self.hostingController = hosting
        self.panel = panel
    }

    private func reposition() {
        guard let panel else { return }
        guard let geometry = NotchGeometry.current(expandedHeight: expandedHeight) else { return }
        panel.setFrame(geometry.panelFrameInScreenCoordinates(), display: true)
    }

    private func repositionIfNeeded() {
        guard panel?.isVisible == true else { return }
        reposition()
    }
}

/// A borderless, non-activating panel that floats above the menu bar.
private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // Allow the panel to receive mouse events even though it's non-activating.
    override var acceptsFirstResponder: Bool { false }
}
