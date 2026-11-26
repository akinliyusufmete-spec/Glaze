import SwiftUI

/// The floating tooltip: name, explanation and a keyboard-shortcut chip.
struct HintBubble: View {
    let hint: Hint

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(hint.title).font(.system(size: 12, weight: .semibold))
                if let line = hint.shortcutLine {
                    Text(line)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.14)))
                        .opacity(line == "No shortcut set" ? 0.6 : 1)
                }
            }
            if let detail = hint.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: 260, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(0.14)))
        .padding(6)                                    // room for the window shadow
        .fixedSize()
    }
}
