import CoreGraphics
import Foundation

/// A freehand stroke: a polyline rendered as a smoothed, round-capped path.
///
/// Phase 2 renders constant width; pressure/brush styles arrive in Phase 3.
struct StrokeElement: Element {
    let id: UUID
    let points: [CGPoint]
    let color: CGColor
    let width: CGFloat
    var transform: CGAffineTransform

    /// Built once; strokes are immutable so the path never goes stale.
    private let path: CGPath
    private let localBounds: CGRect

    init(
        id: UUID = UUID(),
        points: [CGPoint],
        color: CGColor,
        width: CGFloat,
        transform: CGAffineTransform = .identity
    ) {
        self.id = id
        self.points = points
        self.color = color
        self.width = width
        self.transform = transform
        self.path = Self.makePath(points)
        self.localBounds = PolylineGeometry.boundingRect(of: points)
    }

    // DECISION: element identity is its id. Two strokes with the same id are the
    // same element (e.g. the live preview and its committed copy), and comparing
    // whole point arrays on every Set/diff operation would be wasted work.
    static func == (lhs: StrokeElement, rhs: StrokeElement) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var bounds: CGRect {
        guard !localBounds.isNull else { return .null }
        let pad = width / 2 + 1
        return localBounds.insetBy(dx: -pad, dy: -pad).applying(transform)
    }

    func draw(in context: CGContext) {
        guard !points.isEmpty else { return }
        context.saveGState()
        context.concatenate(transform)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(width)
        context.setStrokeColor(color)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }

    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        guard !points.isEmpty else { return false }
        let local = point.applying(transform.inverted())
        let reach = width / 2 + tolerance
        // Cheap reject first. Padded by 1pt because `CGRect.contains` excludes the
        // max edges, and a point exactly `reach` away must still hit.
        guard localBounds.insetBy(dx: -reach - 1, dy: -reach - 1).contains(local) else { return false }
        return PolylineGeometry.distance(from: local, toPolyline: points) <= reach
    }

    /// Midpoint quadratic smoothing: each input point becomes a control point and
    /// the curve passes through the midpoints between samples.
    private static func makePath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else {
            // A click with no drag: a tiny segment so the round cap draws a dot.
            path.addLine(to: CGPoint(x: first.x + 0.01, y: first.y))
            return path
        }
        for i in 1..<points.count {
            let mid = CGPoint(x: (points[i - 1].x + points[i].x) / 2, y: (points[i - 1].y + points[i].y) / 2)
            if i == 1 {
                path.addLine(to: mid)
            } else {
                path.addQuadCurve(to: mid, control: points[i - 1])
            }
        }
        path.addLine(to: points[points.count - 1])
        return path
    }
}
