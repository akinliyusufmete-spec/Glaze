import SwiftUI

struct ToolbarView: View {
    let entries: [ToolbarEntry]
    let actions: ToolbarActions
    let state: ToolbarState
    let settings: ToolSettings

    var body: some View {
        HStack(spacing: 2) {
            WindowDragHandle()
                .frame(width: 14, height: 30)
                .overlay(Image(systemName: "line.3.vertical").font(.system(size: 9)).opacity(0.4).allowsHitTesting(false))

            ForEach(entries) { entry in
                switch entry.kind {
                case .separator:
                    Divider().frame(height: 18).padding(.horizontal, 3)
                case .tool:
                    ToolbarButton(entry: entry, isSelected: state.selectedToolID == entry.id, isEnabled: true) {
                        actions.selectTool(entry.id)
                    }
                case .action:
                    ToolbarButton(entry: entry, isSelected: false,
                                  isEnabled: !state.disabledActionIDs.contains(entry.id)) {
                        actions.perform(entry.id)
                    }
                }
            }

            Divider().frame(height: 18).padding(.horizontal, 3)
            colorSwatch
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.12)))
        .fixedSize()
    }

    private var colorSwatch: some View {
        Button(action: actions.toggleColorPanel) {
            Circle()
                .fill(settings.strokeColor.swiftUIColor)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.35), lineWidth: 1))
                .frame(width: 20, height: 20)
                .padding(5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(state.isColorPanelVisible ? Color.accentColor.opacity(0.28) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Color (C picks from screen)")
        .accessibilityLabel("Color")
    }
}
