import AppKit

/// A drawing tool. Receives one gesture at a time: `begin`, any number of
/// `move`s, then `end` or `cancel`. Changes the canvas only via `ToolContext.perform`.
@MainActor
protocol Tool: AnyObject {
    var id: ToolID { get }
    var cursor: NSCursor { get }
    func begin(_ point: InputPoint, context: any ToolContext)
    func move(_ point: InputPoint, context: any ToolContext)
    func end(_ point: InputPoint, context: any ToolContext)
    /// Abandons the gesture without committing anything.
    func cancel(context: any ToolContext)
    func modifiersChanged(_ flags: NSEvent.ModifierFlags, context: any ToolContext)
}

extension Tool {
    func modifiersChanged(_ flags: NSEvent.ModifierFlags, context: any ToolContext) {}
}
