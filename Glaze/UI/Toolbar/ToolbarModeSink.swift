import Foundation

/// Keeps the toolbar in step with the app mode: it shows in Draw mode (if enabled in
/// preferences), hides in Pointer mode, and highlights the active tool.
@MainActor
final class ToolbarModeSink: ModeSink {
    private let toolbar: ToolbarController
    private let colorPanel: ColorPanelController
    private let state: ToolbarState
    private let preferences: Preferences

    init(toolbar: ToolbarController, colorPanel: ColorPanelController,
         state: ToolbarState, preferences: Preferences) {
        self.toolbar = toolbar
        self.colorPanel = colorPanel
        self.state = state
        self.preferences = preferences
    }

    func apply(mode: AppMode, previous: AppMode?) {
        switch mode {
        case let .draw(tool):
            state.selectedToolID = tool.rawValue
            if preferences.showToolbar { toolbar.show() } else { hidePanels() }
        case .pointer:
            state.selectedToolID = nil
            hidePanels()
        case .momentaryDraw:
            break   // a held-key stroke shouldn't make the panels flash in and out
        }
    }

    /// Re-applies visibility after the "show toolbar" preference changes.
    func refresh(mode: AppMode) { apply(mode: mode, previous: mode) }

    private func hidePanels() {
        colorPanel.hide()
        toolbar.hide()
    }
}
