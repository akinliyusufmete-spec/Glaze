import AppKit

/// Maps tool IDs to factories. New tools register here and nowhere else.
@MainActor
final class ToolRegistry {
    typealias Factory = @MainActor () -> any Tool

    private var factories: [ToolID: Factory] = [:]

    /// Brushes that commit strokes. The laser is a brush too but never commits;
    /// LaserTool arrives in Phase 5.
    static let brushIDs: [ToolID] = [.pen, .marker, .highlighter, .pencil, .calligraphy, .neon, .dashed]

    /// - Parameter settings: the shared color/size choices. Without them (tests) brushes use
    ///   fixed colors: yellow for the highlighter, red for the rest.
    init(settings: ToolSettings? = nil) {
        for id in Self.brushIDs {
            guard let style = BrushPresets.preset(for: id) else { continue }
            if let settings {
                register(id) { BrushTool(id: id, style: style, settings: settings) }
            } else {
                let color: NSColor = id == .highlighter ? .systemYellow : .systemRed
                register(id) { BrushTool(id: id, style: style, color: color) }
            }
        }
        register(.eraser) { EraserTool(settings: settings) }
        register(.laser) { LaserTool(settings: settings) }
    }

    func register(_ id: ToolID, factory: @escaping Factory) {
        factories[id] = factory
    }

    func isImplemented(_ id: ToolID) -> Bool { factories[id] != nil }

    /// A fresh instance of the tool.
    // DECISION: IDs with no tool yet (shapes, laser, …) fall back to the pen,
    // so selecting a not-yet-built tool still draws instead of doing nothing.
    func makeTool(_ id: ToolID) -> any Tool {
        (factories[id] ?? factories[.pen] ?? { BrushTool() })()
    }
}
