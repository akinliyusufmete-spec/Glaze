import Foundation
import Observation

/// Everything the toolbar can ask the app to do. `AppEnvironment` wires these up.
struct ToolbarActions {
    var selectTool: (String) -> Void = { _ in }
    var perform: (String) -> Void = { _ in }          // action entries, by id
    var toggleColorPanel: () -> Void = {}
}

/// Observable state the toolbar view renders. The app pushes changes in; the view never mutates it.
@MainActor
@Observable
final class ToolbarState {
    var selectedToolID: String?
    var isColorPanelVisible = false
    var disabledActionIDs: Set<String> = []

    init(selectedToolID: String? = nil) {
        self.selectedToolID = selectedToolID
    }
}
