import Combine
import Foundation

/// Everything the toolbar can ask the app to do. The app wires these up in `AppEnvironment`.
struct ToolbarActions {
    var selectTool: (String) -> Void = { _ in }
    var perform: (String) -> Void = { _ in }          // action entries, by id
    var toggleColorPanel: () -> Void = {}
    var quit: () -> Void = {}
}

/// Observable state the toolbar view renders. The app pushes changes in; the view never mutates it.
final class ToolbarState: ObservableObject {
    @Published var selectedToolID: String?
    @Published var color: RGBAColor
    @Published var isColorPanelVisible = false
    @Published var disabledActionIDs: Set<String> = []

    init(selectedToolID: String? = nil, color: RGBAColor) {
        self.selectedToolID = selectedToolID
        self.color = color
    }
}
