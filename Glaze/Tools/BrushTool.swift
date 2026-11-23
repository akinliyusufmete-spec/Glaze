import AppKit

/// Freehand pen. Builds a `StrokeElement` on the live layer while dragging and
/// commits it with one `AddElement` on mouse-up.
@MainActor
final class BrushTool: Tool {
    let id: ToolID = .pen

    // DECISION: fixed red 4 pt until Phase 3 adds BrushStyle and the palette.
    let color: NSColor = .systemRed
    let width: CGFloat = 4

    private(set) lazy var cursor: NSCursor = BrushCursor.make(diameter: width, color: color)

    private var strokeID = UUID()
    private var points: [CGPoint] = []
    private var cgColor: CGColor { color.cgColor }

    var isDrawing: Bool { !points.isEmpty }

    func begin(_ point: InputPoint, context: any ToolContext) {
        strokeID = UUID()
        points = [point.location]
        publish(context: context)
    }

    func move(_ point: InputPoint, context: any ToolContext) {
        guard isDrawing else { return begin(point, context: context) }
        guard point.location != points.last else { return }
        points.append(point.location)
        publish(context: context)
    }

    func end(_ point: InputPoint, context: any ToolContext) {
        guard isDrawing else { return }
        if point.location != points.last {
            points.append(point.location)
        }
        let stroke = makeStroke()
        points = []
        context.perform(AddElement(element: stroke))
        context.showLive(nil, dirty: nil)
    }

    func cancel(context: any ToolContext) {
        points = []
        context.showLive(nil, dirty: nil)
    }

    private func makeStroke() -> StrokeElement {
        StrokeElement(id: strokeID, points: points, color: cgColor, width: width)
    }

    /// Only the last few points change the smoothed path, so that's all the
    /// live layer has to repaint.
    private func publish(context: any ToolContext) {
        let tail = Array(points.suffix(3))
        let pad = width / 2 + 2
        let dirty = PolylineGeometry.boundingRect(of: tail).insetBy(dx: -pad, dy: -pad)
        context.showLive(makeStroke(), dirty: dirty)
    }
}
