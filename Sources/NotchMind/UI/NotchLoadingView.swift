import SwiftUI

/// Three bouncing dots shown while the first token is in flight.
struct NotchLoadingView: View {
    let prompt: String
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(NotchPalette.accent)
                    .frame(width: 7, height: 7)
                    .offset(y: sin(phase + Double(i) * .pi / 1.5) * 4)
            }
            if !prompt.isEmpty {
                Text(prompt)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotchPalette.textSecondary)
                    .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: true)) { phase = .pi } }
    }
}
