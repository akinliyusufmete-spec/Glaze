import Foundation

/// Maps tool IDs to factories. New tools register here and nowhere else.
@MainActor
final class ToolRegistry {
    typealias Factory = @MainActor () -> any Tool

    private var factories: [ToolID: Factory] = [:]

    init() {
        register(.pen) { BrushTool() }
        register(.eraser) { EraserTool() }
    }

    func register(_ id: ToolID, factory: @escaping Factory) {
        factories[id] = factory
    }

    func isImplemented(_ id: ToolID) -> Bool { factories[id] != nil }

    /// A fresh instance of the tool.
    // DECISION: IDs with no tool yet (marker, shapes, …) fall back to the pen,
    // so selecting a not-yet-built tool still draws instead of doing nothing.
    func makeTool(_ id: ToolID) -> any Tool {
        (factories[id] ?? factories[.pen] ?? { BrushTool() })()
    }
}
