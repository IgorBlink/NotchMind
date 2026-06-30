import SwiftUI

/// The resting state — a small pill that hugs the hardware notch.
///
/// On non-notched Macs this is the top-center floating pill. We render a tiny
/// "spark" glyph so the surface isn't a dead black rectangle.
struct NotchCollapsedView: View {
    var body: some View {
        Image(systemName: "brain.head.profile")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(NotchPalette.accent.opacity(0.85))
            .opacity(0.0)  // hidden by default; only shown on hover if desired
    }
}
