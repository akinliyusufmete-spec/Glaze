import SwiftUI

/// The small rounded pill that names the current mode.
struct ModePillView: View {
    let mode: AppMode

    private var symbol: String {
        mode.capturesInput ? "pencil.tip" : "cursorarrow"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
            Text(mode.displayName)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.black.opacity(0.72)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .fixedSize()
    }
}
