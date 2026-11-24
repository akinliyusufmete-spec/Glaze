import AppKit

/// Every freehand brush. Filters input with One-Euro, shows the stroke on the
/// live layer while dragging and commits it with one `AddElement` on mouse-up.
/// The brush's look comes entirely from its `BrushStyle`.
@MainActor
final class BrushTool: Tool {
    let id: ToolID
    let style: BrushStyle
    // DECISION: color stays fixed per tool until Phase 4 adds the palette.
    let color: NSColor

    private(set) lazy var cursor: NSCursor = BrushCursor.make(diameter: style.baseWidth, color: color)

    private var strokeID = UUID()
    private var samples: [InputPoint] = []
    private var filter = OneEuroFilter()
    private var lastRaw: CGPoint?
    private var lastDirty: CGRect = .null
    private var cgColor: CGColor { color.cgColor }

    var isDrawing: Bool { !samples.isEmpty }

    init(id: ToolID = .pen, style: BrushStyle = BrushPresets.pen, color: NSColor = .systemRed) {
        self.id = id
        self.style = style
        self.color = color
    }

    func begin(_ point: InputPoint, context: any ToolContext) {
        strokeID = UUID()
        filter.reset()
        lastDirty = .null
        lastRaw = point.location
        samples = [filter.filter(point)]
        publish(context: context)
    }

    func move(_ point: InputPoint, context: any ToolContext) {
        guard isDrawing else { return begin(point, context: context) }
        guard point.location != lastRaw else { return }
        lastRaw = point.location
        samples.append(filter.filter(point))
        publish(context: context)
    }

    func end(_ point: InputPoint, context: any ToolContext) {
        guard isDrawing else { return }
        // DECISION: the filter lags the pointer slightly; the stroke ends
        // exactly where the user let go instead of a few points short.
        var final = point
        if let last = samples.last { final.pressure = last.pressure }
        if samples.count > 1 || point.location != samples[0].location {
            if point.location == lastRaw, samples.count > 1 { samples.removeLast() }
            samples.append(final)
        }
        if style.autoStraighten, samples.count > 2,
           PolylineGeometry.isNearlyStraight(samples.map(\.location)) {
            samples = [samples[0], samples[samples.count - 1]]
        }
        let stroke = makeStroke()
        samples = []
        lastRaw = nil
        context.perform(AddElement(element: stroke))
        context.showLive(nil, dirty: nil)
    }

    func cancel(context: any ToolContext) {
        samples = []
        lastRaw = nil
        context.showLive(nil, dirty: nil)
    }

    private func makeStroke() -> StrokeElement {
        StrokeElement(id: strokeID, samples: samples, style: style, color: cgColor)
    }

    /// Only the tail of the stroke (and an end taper's reach) changes per
    /// event, so that's all the live layer repaints. The previous tail is
    /// included because a taper that moved forward leaves the old one behind.
    private func publish(context: any ToolContext) {
        let stroke = makeStroke()
        let tail = stroke.tailBounds(fromSample: samples.count - 3, extraLength: style.taper.end)
        context.showLive(stroke, dirty: tail.union(lastDirty))
        lastDirty = tail
    }
}
