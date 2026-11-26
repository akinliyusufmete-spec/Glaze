import AppKit

/// Every freehand brush. Filters input with One-Euro, shows the stroke on the
/// live layer while dragging and commits it with one `AddElement` on mouse-up.
/// The brush's look comes entirely from its `BrushStyle`.
@MainActor
final class BrushTool: Tool {
    let id: ToolID
    /// The brush's preset. The width actually drawn may differ (see `currentStyle`).
    let style: BrushStyle
    /// Used when there are no `ToolSettings` (tests); otherwise the settings' stroke color wins.
    private let fixedColor: NSColor
    private let settings: ToolSettings?

    // DECISION: color and width are read from `ToolSettings` when a stroke begins and kept
    // for that stroke, so changing the color mid-drag never recolors a stroke in progress.
    private var activeStyle: BrushStyle
    private var activeColor: CGColor

    private var currentColor: NSColor { settings?.strokeColor.nsColor ?? fixedColor }
    private var currentStyle: BrushStyle {
        guard let width = settings?.width(for: id) else { return style }
        var s = style
        s.baseWidth = width
        return s
    }

    var color: NSColor { currentColor }

    private var cachedCursor: (key: String, cursor: NSCursor)?
    /// A ring that previews the brush size in the current color; rebuilt when either changes.
    var cursor: NSCursor {
        let width = currentStyle.baseWidth
        let color = currentColor
        let key = "\(width)-\(color.hashValue)"
        if let cached = cachedCursor, cached.key == key { return cached.cursor }
        let made = BrushCursor.make(diameter: width, color: color)
        cachedCursor = (key, made)
        return made
    }

    private var strokeID = UUID()
    private var samples: [InputPoint] = []
    private var filter = OneEuroFilter()
    private var lastRaw: CGPoint?
    private var lastDirty: CGRect = .null

    var isDrawing: Bool { !samples.isEmpty }

    init(id: ToolID = .pen, style: BrushStyle = BrushPresets.pen, color: NSColor = .systemRed) {
        self.id = id
        self.style = style
        self.fixedColor = color
        self.settings = nil
        self.activeStyle = style
        self.activeColor = color.cgColor
    }

    init(id: ToolID, style: BrushStyle, settings: ToolSettings) {
        self.id = id
        self.style = style
        self.fixedColor = settings.strokeColor.nsColor
        self.settings = settings
        self.activeStyle = style
        self.activeColor = settings.strokeColor.cgColor
    }

    func begin(_ point: InputPoint, context: any ToolContext) {
        strokeID = UUID()
        activeStyle = currentStyle
        activeColor = currentColor.cgColor
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
        if activeStyle.autoStraighten, samples.count > 2,
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
        StrokeElement(id: strokeID, samples: samples, style: activeStyle, color: activeColor)
    }

    /// Only the tail of the stroke (and an end taper's reach) changes per
    /// event, so that's all the live layer repaints. The previous tail is
    /// included because a taper that moved forward leaves the old one behind.
    private func publish(context: any ToolContext) {
        let stroke = makeStroke()
        let tail = stroke.tailBounds(fromSample: samples.count - 3, extraLength: activeStyle.taper.end)
        context.showLive(stroke, dirty: tail.union(lastDirty))
        lastDirty = tail
    }
}
