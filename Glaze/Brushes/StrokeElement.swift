import CoreGraphics
import Foundation

/// A freehand stroke: raw input samples plus the brush that paints them.
/// Geometry is derived once at init; strokes are immutable, so it never goes
/// stale.
struct StrokeElement: Element {
    let id: UUID
    let samples: [InputPoint]
    let style: BrushStyle
    let color: CGColor
    var transform: CGAffineTransform

    private let geometry: StrokeGeometry

    init(
        id: UUID = UUID(),
        samples: [InputPoint],
        style: BrushStyle,
        color: CGColor,
        transform: CGAffineTransform = .identity
    ) {
        self.id = id
        self.samples = samples
        self.style = style
        self.color = color
        self.transform = transform
        var noise = SeededNoise(uuid: id)
        self.geometry = StrokeGeometry(samples: samples, style: style, seed: noise.next())
    }

    /// A plain constant-width round stroke through `points` at full pressure.
    init(
        id: UUID = UUID(),
        points: [CGPoint],
        color: CGColor,
        width: CGFloat,
        transform: CGAffineTransform = .identity
    ) {
        self.init(
            id: id,
            samples: points.map { InputPoint(location: $0) },
            style: BrushPresets.uniform(width: width),
            color: color,
            transform: transform
        )
    }

    // DECISION: element identity is its id. Two strokes with the same id are the
    // same element (e.g. the live preview and its committed copy), and comparing
    // whole point arrays on every Set/diff operation would be wasted work.
    static func == (lhs: StrokeElement, rhs: StrokeElement) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// The input sample locations (local coordinates).
    var points: [CGPoint] { samples.map(\.location) }
    var width: CGFloat { style.baseWidth }
    var blendMode: CGBlendMode { style.blendMode }

    var bounds: CGRect {
        let local = geometry.localBounds
        return local.isNull ? .null : local.applying(transform)
    }

    func draw(in context: CGContext) {
        context.saveGState()
        context.concatenate(transform)
        StrokeRenderer.draw(geometry, color: color, in: context)
        context.restoreGState()
    }

    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        geometry.hitTest(point.applying(transform.inverted()), tolerance: tolerance)
    }

    /// Canvas-space bounds of what changed when samples from `sample` onward
    /// were added, plus `extraLength` of arc before the end (end tapers).
    func tailBounds(fromSample sample: Int, extraLength: CGFloat) -> CGRect {
        let local = geometry.tailBounds(fromControl: sample, extraLength: extraLength)
        return local.isNull ? .null : local.applying(transform)
    }
}
