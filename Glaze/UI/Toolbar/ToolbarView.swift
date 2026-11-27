import SwiftUI

struct ToolbarView: View {
    let entries: [ToolbarEntry]
    let actions: ToolbarActions
    let state: ToolbarState
    let settings: ToolSettings
    let placement: ToolbarPlacement

    private var vertical: Bool { placement.isVertical }
    private var selectedTool: ToolID? { state.selectedToolID.flatMap(ToolID.init) }

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 2))
        layout {
            // Only a floating toolbar can be dragged; a docked one is anchored to its edge.
            if placement == .floating { dragHandle }

            ForEach(entries) { entry in
                switch entry.kind {
                case .separator:
                    separator
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

            separator
            SizeSlider(tool: selectedTool, settings: settings, vertical: vertical)
            separator
            colorSwatch
        }
        .padding(.horizontal, vertical ? 5 : 6)
        .padding(.vertical, vertical ? 6 : 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.12)))
        .fixedSize()
    }

    private var dragHandle: some View {
        WindowDragHandle()
            .frame(width: vertical ? 30 : 14, height: vertical ? 14 : 30)
            .overlay(Image(systemName: vertical ? "line.3.horizontal" : "line.3.vertical")
                .font(.system(size: 9)).opacity(0.4).allowsHitTesting(false))
            .hint(Hint(title: "Move", detail: "Drag to move the toolbar. Choose a screen edge in Settings to dock it instead."))
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.18))
            .frame(width: vertical ? 18 : 1, height: vertical ? 1 : 18)
            .padding(vertical ? .vertical : .horizontal, 3)
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
        .hint(action: "toggleColorPanel")
        .accessibilityLabel("Color")
    }
}
