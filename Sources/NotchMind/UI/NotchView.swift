import SwiftUI

/// The root SwiftUI view hosted in the notch `NSPanel`.
///
/// Renders a top-aligned, black, continuous-cornered container that hugs the
/// hardware notch when collapsed and grows downward to show content. The
/// container's height is driven by the current `NotchState` so the spring
/// animation smoothly expands/collapses.
struct NotchView: View {

    @ObservedObject var viewModel: NotchViewModel
    @State private var hovered = false

    /// Hardware notch height on the current screen. Content starts below this
    /// so the visible "lips" of the notch always match the hardware.
    private var notchInset: CGFloat {
        NotchGeometry.current(expandedHeight: 320)?.notchHeight ?? 32
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(NotchPalette.background)
                    .shadow(color: .black.opacity(0.55), radius: 16, x: 0, y: 8)

                content
                    .padding(.top, notchInset + (isCollapsed ? 0 : 10))
                    .padding(.horizontal, isCollapsed ? 0 : 18)
                    .padding(.bottom, isCollapsed ? 0 : 14)
                    .frame(maxWidth: isCollapsed ? 0 : .infinity,
                           alignment: .leading)
            }
            .frame(width: containerWidth,
                   height: containerHeight)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .animation(.spring(response: 0.35, dampingFraction: 0.78),
                   value: animationSeed)
        .onHover { hovered = $0 }
        .onTapGesture { viewModel.dismiss() }
        .onAppear { installEscapeMonitor() }
        .onDisappear { removeEscapeMonitor() }
    }

    // MARK: - State routing

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            NotchCollapsedView()
        case .loading(let prompt):
            NotchLoadingView(prompt: prompt)
        case .streaming(let text, let done):
            NotchExpandedView(text: text,
                              done: done,
                              usedClipboardFallback: viewModel.usedClipboardFallback,
                              fontSize: SettingsStore.shared.fontSize)
        case .toast(let message, let systemImage):
            NotchToastView(message: message, systemImage: systemImage)
        case .error(let message):
            NotchErrorView(message: message)
        }
    }

    // MARK: - Sizing

    private var isCollapsed: Bool {
        viewModel.state == .idle
    }

    private var containerWidth: CGFloat {
        guard let g = NotchGeometry.current(expandedHeight: 320) else { return 240 }
        return g.hasNotch ? g.notchWidth + 32 : g.notchWidth
    }

    private var containerHeight: CGFloat {
        switch viewModel.state {
        case .idle:
            return notchInset
        case .loading:
            return notchInset + 56
        case .streaming(let text, _):
            return notchInset + min(textHeight(text), maxExpandedHeight)
        case .toast:
            return notchInset + 48
        case .error(let m):
            return notchInset + min(textHeight(m) + 24, 160)
        }
    }

    private var maxExpandedHeight: CGFloat {
        SettingsStore.shared.maxExpandedHeight
    }

    private func textHeight(_ s: String) -> CGFloat {
        let approx = CGFloat(s.count) / 38.0 * 18.0  // rough chars-per-line * line height
        return max(approx, 56)
    }

    private var animationSeed: String {
        switch viewModel.state {
        case .idle: return "idle"
        case .loading: return "loading"
        case .streaming(_, let done): return done ? "stream-done" : "stream"
        case .toast: return "toast"
        case .error: return "error"
        }
    }

    // MARK: - Esc to dismiss

    @State private var escMonitor: Any?

    private func installEscapeMonitor() {
        guard escMonitor == nil else { return }
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak viewModel] event in
            if event.keyCode == 53 {  // Esc
                viewModel?.dismiss()
                return nil
            }
            return event
        }
    }

    private func removeEscapeMonitor() {
        if let m = escMonitor { NSEvent.removeMonitor(m) }
        escMonitor = nil
    }
}

enum NotchPalette {
    static let background = Color.black
    static let text = Color.white
    static let textSecondary = Color.white.opacity(0.65)
    static let accent = Color(red: 0.35, green: 0.62, blue: 1.0)
}
