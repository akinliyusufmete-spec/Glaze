import CoreGraphics
import Foundation

/// Builds fillable outlines for variable-width strokes. Pure geometry.
///
/// Every subpath is wound counter-clockwise (positive shoelace area in y-up
/// coordinates), so a single nonzero-winding fill draws their union with no
/// seams and no holes where pieces overlap.
enum StrokeOutline {
    /// Joints whose neighbouring segments leave a gap smaller than this (pt)
    /// on both sides don't need a round-join circle.
    static let jointGapTolerance: CGFloat = 0.3

    /// The union of round "capsules" along a centerline whose radius varies
    /// per point: a circle at each end, a tangent quad per segment, and a
    /// circle at joints where the quads would leave a wedge uncovered.
    /// Segments whose bounds miss `clip` are skipped.
    static func capsules(points: [CGPoint], radii: [CGFloat], clip: CGRect? = nil) -> CGPath {
        let path = CGMutablePath()
        addCapsules(to: path, points: points, radii: radii, clip: clip)
        return path
    }

    /// A broad-nib (calligraphy) outline: the nib is a line segment of
    /// half-extent `vectors[i]` swept along the centerline. Thin hairline
    /// capsules keep strokes drawn parallel to the nib visible.
    static func nib(points: [CGPoint], vectors: [CGVector], clip: CGRect? = nil) -> CGPath {
        let path = CGMutablePath()
        let n = min(points.count, vectors.count)
        guard n > 0 else { return path }
        if n == 1 {
            let c = points[0], h = vectors[0]
            let len = max(hypot(h.dx, h.dy), 1e-6)
            let e = CGVector(dx: -h.dy / len * 0.6, dy: h.dx / len * 0.6)
            addQuad(to: path, [
                CGPoint(x: c.x + h.dx + e.dx, y: c.y + h.dy + e.dy),
                CGPoint(x: c.x - h.dx + e.dx, y: c.y - h.dy + e.dy),
                CGPoint(x: c.x - h.dx - e.dx, y: c.y - h.dy - e.dy),
                CGPoint(x: c.x + h.dx - e.dx, y: c.y + h.dy - e.dy),
            ])
            return path
        }
        for i in 0..<(n - 1) {
            let c0 = points[i], c1 = points[i + 1]
            let h0 = vectors[i], h1 = vectors[i + 1]
            if let clip {
                let pad = max(hypot(h0.dx, h0.dy), hypot(h1.dx, h1.dy)) + 1
                let box = CGRect(
                    x: min(c0.x, c1.x), y: min(c0.y, c1.y),
                    width: abs(c1.x - c0.x), height: abs(c1.y - c0.y)
                ).insetBy(dx: -pad, dy: -pad)
                guard box.intersects(clip) else { continue }
            }
            addQuad(to: path, [
                CGPoint(x: c0.x + h0.dx, y: c0.y + h0.dy),
                CGPoint(x: c1.x + h1.dx, y: c1.y + h1.dy),
                CGPoint(x: c1.x - h1.dx, y: c1.y - h1.dy),
                CGPoint(x: c0.x - h0.dx, y: c0.y - h0.dy),
            ])
        }
        addCapsules(to: path, points: Array(points[0..<n]), radii: Array(repeating: 0.6, count: n), clip: clip)
        return path
    }

    // MARK: - Pieces

    private static func addCapsules(to path: CGMutablePath, points: [CGPoint], radii: [CGFloat], clip: CGRect?) {
        let n = min(points.count, radii.count)
        guard n > 0 else { return }
        func visible(_ c: CGPoint, _ r: CGFloat) -> Bool {
            guard let clip else { return true }
            return CGRect(x: c.x - r - 1, y: c.y - r - 1, width: 2 * r + 2, height: 2 * r + 2).intersects(clip)
        }
        guard n > 1 else {
            if visible(points[0], radii[0]) { addCircle(to: path, points[0], radii[0]) }
            return
        }

        // Tangent points where the previous segment's quad ends: (left, right).
        var previousEnd: (CGPoint, CGPoint)?
        for i in 0..<(n - 1) {
            let c0 = points[i], c1 = points[i + 1]
            let r0 = radii[i], r1 = radii[i + 1]
            let segmentVisible: Bool = {
                guard let clip else { return true }
                let pad = max(r0, r1) + 1
                return CGRect(
                    x: min(c0.x, c1.x), y: min(c0.y, c1.y),
                    width: abs(c1.x - c0.x), height: abs(c1.y - c0.y)
                ).insetBy(dx: -pad, dy: -pad).intersects(clip)
            }()

            let dx = c1.x - c0.x, dy = c1.y - c0.y
            let d = hypot(dx, dy)
            guard d > abs(r1 - r0), d > 0 else {
                // One circle swallows the other; no tangent quad exists.
                if segmentVisible {
                    if r0 >= r1 { addCircle(to: path, c0, r0) } else { addCircle(to: path, c1, r1) }
                }
                previousEnd = nil
                continue
            }
            let ux = dx / d, uy = dy / d
            let nx = -uy, ny = ux
            let a = (r0 - r1) / d
            let b = (1 - a * a).squareRoot()
            let mL = CGVector(dx: a * ux + b * nx, dy: a * uy + b * ny)
            let mR = CGVector(dx: a * ux - b * nx, dy: a * uy - b * ny)
            let startL = CGPoint(x: c0.x + r0 * mL.dx, y: c0.y + r0 * mL.dy)
            let startR = CGPoint(x: c0.x + r0 * mR.dx, y: c0.y + r0 * mR.dy)
            let endL = CGPoint(x: c1.x + r1 * mL.dx, y: c1.y + r1 * mL.dy)
            let endR = CGPoint(x: c1.x + r1 * mR.dx, y: c1.y + r1 * mR.dy)

            // Circle at the start of the stroke, or at a joint that would leave a wedge.
            let needsCircle: Bool = {
                guard i > 0, let prev = previousEnd else { return true }
                return distance(prev.0, startL) > jointGapTolerance || distance(prev.1, startR) > jointGapTolerance
            }()
            if needsCircle, visible(c0, r0) { addCircle(to: path, c0, r0) }
            // DECISION: a joint close enough to skip its circle still leaves a
            // sub-pixel wedge between the two quads, which shows as a lighter
            // column in translucent ink. Starting this quad on the previous
            // quad's end points makes them share an edge exactly.
            let (qL, qR) = needsCircle ? (startL, startR) : (previousEnd?.0 ?? startL, previousEnd?.1 ?? startR)
            if segmentVisible { addQuad(to: path, [qL, endL, endR, qR]) }
            previousEnd = (endL, endR)
        }
        if visible(points[n - 1], radii[n - 1]) { addCircle(to: path, points[n - 1], radii[n - 1]) }
    }

    private static func addCircle(to path: CGMutablePath, _ c: CGPoint, _ r: CGFloat) {
        guard r > 0 else { return }
        path.move(to: CGPoint(x: c.x + r, y: c.y))
        path.addArc(center: c, radius: r, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        path.closeSubpath()
    }

    /// Adds a quad, reversed if needed so its winding is counter-clockwise.
    private static func addQuad(to path: CGMutablePath, _ q: [CGPoint]) {
        let ordered = signedArea(q) >= 0 ? q : q.reversed()
        path.addLines(between: ordered)
        path.closeSubpath()
    }

    /// Shoelace signed area: positive for counter-clockwise in y-up coordinates.
    static func signedArea(_ polygon: [CGPoint]) -> CGFloat {
        guard polygon.count > 2 else { return 0 }
        var sum: CGFloat = 0
        for i in 0..<polygon.count {
            let a = polygon[i], b = polygon[(i + 1) % polygon.count]
            sum += a.x * b.y - b.x * a.y
        }
        return sum / 2
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
