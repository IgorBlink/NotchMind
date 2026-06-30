import SwiftUI

/// Compact confirmation toast for the capture flow.
struct NotchToastView: View {
    let message: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NotchPalette.accent)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NotchPalette.text)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Inline error display.
struct NotchErrorView: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(NotchPalette.text)
                .lineLimit(4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
