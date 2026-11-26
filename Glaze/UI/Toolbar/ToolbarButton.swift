import SwiftUI

struct ToolbarButton: View {
    let entry: ToolbarEntry
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            icon
                .font(.system(size: 15, weight: .medium))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? Color.accentColor.opacity(0.28) : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .hint(entry.hint)
        .accessibilityLabel(entry.title)
    }

    @ViewBuilder private var icon: some View {
        if let name = entry.resolvedSymbol {
            Image(systemName: name)
        } else {
            // No symbol available on this macOS: fall back to the first letter.
            Text(String(entry.title.prefix(1)))
        }
    }
}
