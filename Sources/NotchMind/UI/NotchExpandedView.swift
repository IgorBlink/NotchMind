import SwiftUI

/// The streaming explanation view — token-by-token text in a scrollable area.
struct NotchExpandedView: View {
    let text: String
    let done: Bool
    let usedClipboardFallback: Bool
    let fontSize: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.vertical, showsIndicators: false) {
                Text(text.isEmpty && !done ? "…" : text)
                    .font(.system(size: fontSize, weight: .regular))
                    .foregroundStyle(NotchPalette.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(2)
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 6) {
                if usedClipboardFallback {
                    Label("read via clipboard", systemImage: "doc.on.clipboard")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NotchPalette.textSecondary)
                }
                if done {
                    Label("dismiss", systemImage: "esc")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NotchPalette.textSecondary)
                }
            }
        }
    }
}
