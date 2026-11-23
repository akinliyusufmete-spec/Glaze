import Foundation

/// The app's single source of truth for "who gets the mouse".
indirect enum AppMode: Hashable, Sendable {
    /// Overlay is visible but click-through.
    case pointer
    /// Overlay captures input with the given tool.
    case draw(tool: ToolID)
    /// Drawing only while a key is held; on release, go back to `returnTo`.
    case momentaryDraw(returnTo: AppMode)

    /// True when the overlay should receive mouse events.
    var capturesInput: Bool {
        switch self {
        case .pointer: false
        case .draw, .momentaryDraw: true
        }
    }

    /// The tool in use, if drawing with an explicit tool.
    var tool: ToolID? {
        if case let .draw(tool) = self { return tool }
        return nil
    }

    var displayName: String {
        switch self {
        case .pointer: "Pointer"
        case let .draw(tool): "Draw · \(tool.displayName)"
        case .momentaryDraw: "Draw (hold)"
        }
    }
}
