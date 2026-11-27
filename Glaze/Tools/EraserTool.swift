import AppKit

/// Stroke eraser: anything the eraser touches during a drag disappears whole.
///
/// DECISION: hit elements are hidden immediately (preview) but only removed on
/// mouse-up, as one `RemoveElements`, so one drag is one undo step.
@MainActor
final class EraserTool: Tool {
    let id: ToolID = .eraser
    static let defaultDiameter: CGFloat = 16

    private let settings: ToolSettings?

    init(settings: ToolSettings? = nil) {
        self.settings = settings
    }

    /// Half the eraser's diameter, which the size slider sets through `ToolSettings`.
    var radius: CGFloat { (settings?.width(for: .eraser) ?? Self.defaultDiameter) / 2 }

    private var cachedCursor: (radius: CGFloat, cursor: NSCursor)?
    var cursor: NSCursor {
        if let cached = cachedCursor, cached.radius == radius { return cached.cursor }
        let made = BrushCursor.make(diameter: radius * 2, color: .systemGray)
        cachedCursor = (radius, made)
        return made
    }

    private var lastPoint: CGPoint?
    private(set) var pending: Set<UUID> = []

    func begin(_ point: InputPoint, context: any ToolContext) {
        pending = []
        lastPoint = point.location
        erase(along: [point.location], context: context)
    }

    func move(_ point: InputPoint, context: any ToolContext) {
        guard let last = lastPoint else { return begin(point, context: context) }
        // Sample the segment so a fast flick can't jump over a thin stroke.
        erase(along: PolylineGeometry.samples(from: last, to: point.location, spacing: radius / 2), context: context)
        lastPoint = point.location
    }

    func end(_ point: InputPoint, context: any ToolContext) {
        guard lastPoint != nil else { return }
        move(point, context: context)
        let command = RemoveElements(ids: pending, in: context.canvas)
        reset(context: context)
        if !command.isEmpty {
            context.perform(command)
        }
    }

    func cancel(context: any ToolContext) {
        reset(context: context)
    }

    private func reset(context: any ToolContext) {
        lastPoint = nil
        pending = []
        context.setPendingRemoval([])
    }

    private func erase(along samples: [CGPoint], context: any ToolContext) {
        let before = pending.count
        for element in context.canvas.elements where !pending.contains(element.id) {
            let reach = element.bounds.insetBy(dx: -radius, dy: -radius)
            if samples.contains(where: { reach.contains($0) && element.hitTest($0, tolerance: radius) }) {
                pending.insert(element.id)
            }
        }
        if pending.count != before {
            context.setPendingRemoval(pending)
        }
    }
}
