import CoreGraphics
import Foundation

/// What a tool can see and do while it handles a gesture on one display.
/// Implemented by `CanvasView`; tests use a fake.
@MainActor
protocol ToolContext: AnyObject {
    /// The display's committed canvas, as it is right now.
    var canvas: Canvas { get }
    /// Commits a change. The only way a tool alters the canvas.
    func perform(_ command: any Command)
    /// Shows an in-progress element on the live layer (nil hides it).
    /// `dirty` is the canvas rect that changed since the last call, if known.
    func showLive(_ element: (any Element)?, dirty: CGRect?)
    /// Elements to hide from the committed layer while a gesture is pending
    /// (the eraser's preview). An empty set shows everything again.
    func setPendingRemoval(_ ids: Set<UUID>)
}
