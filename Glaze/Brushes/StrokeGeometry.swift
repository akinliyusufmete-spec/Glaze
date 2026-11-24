import CoreGraphics
import Foundation

/// Everything about a stroke's shape that depends only on its samples and
/// brush: the smoothed centerline, a radius per point, nib vectors for
/// calligraphy, and bounds. Built once per stroke (or once per live update).
struct StrokeGeometry {
    /// Dense, smoothed centerline points (local coordinates).
    let points: [CGPoint]
    /// Half-width at each point.
    let radii: [CGFloat]
    /// Calligraphy only: the nib's half-extent at each point.
    let nibVectors: [CGVector]?
    /// Arc length from the first point to each point.
    let arcLengths: [CGFloat]
    /// For each input sample, its index in `points`.
    let controlIndices: [Int]
    /// Bounds of `points` alone.
    let pointBounds: CGRect
    /// Bounds of everything the stroke paints, glow included.
    let localBounds: CGRect
    /// True when the renderer strokes `centerline` instead of filling an outline.
    let isUniform: Bool
    /// The centerline as a path, for uniform and dashed strokes.
    let centerline: CGPath

    let style: BrushStyle

    /// Spacing between interpolated points, in points.
    // DECISION: 2pt keeps curves smooth at 2× zoom without bloating long strokes.
    static let spacing: CGFloat = 2

    init(samples: [InputPoint], style: BrushStyle, seed: UInt64) {
        self.style = style
        let curve = CatmullRom.interpolate(samples, spacing: Self.spacing)
        controlIndices = curve.controlIndices

        var arc: [CGFloat] = []
        arc.reserveCapacity(curve.points.count)
        var total: CGFloat = 0
        for (i, p) in curve.points.enumerated() {
            if i > 0 {
                let a = curve.points[i - 1].location
                total += hypot(p.location.x - a.x, p.location.y - a.y)
            }
            arc.append(total)
        }
        arcLengths = arc

        let base = style.baseWidth / 2
        var noise = SeededNoise(seed: seed)
        var pts: [CGPoint] = []
        var rs: [CGFloat] = []
        var nibs: [CGVector] = []
        pts.reserveCapacity(curve.points.count)
        rs.reserveCapacity(curve.points.count)
        for (i, p) in curve.points.enumerated() {
            var r = base * style.pressureCurve.scale(for: p.pressure)
                * style.taper.scale(at: arc[i], length: total)
                * style.tilt.widthScale(for: p.tilt)
            var location = p.location
            if style.jitter > 0 {
                // DECISION: jitter nudges each point by up to `jitter` pt and its
                // radius by up to ±25%·jitter, from a per-stroke seed so redraws
                // and undo/redo reproduce the same grainy edge.
                location.x += noise.nextUnit() * style.jitter
                location.y += noise.nextUnit() * style.jitter
                r *= 1 + 0.25 * style.jitter * noise.nextUnit()
            }
            pts.append(location)
            rs.append(max(r, 0.25))
            if let angle = style.nibAngle {
                let a = style.tilt.nibAngle(base: angle, tilt: p.tilt)
                nibs.append(CGVector(dx: cos(a) * r, dy: sin(a) * r))
            }
        }
        points = pts
        radii = rs
        nibVectors = style.nibAngle == nil ? nil : nibs
        isUniform = style.isUniformWidth || style.dash != nil
        centerline = Self.makeCenterline(pts)

        pointBounds = PolylineGeometry.boundingRect(of: pts)
        let maxR = isUniform ? base : (rs.max() ?? base)
        // Square-ish ends (butt dots drawn as square caps, nib corners) reach
        // up to √2·r from the centerline.
        let cornerFactor: CGFloat = (style.lineCap == .round && nibVectors == nil) ? 1 : 1.415
        var pad = maxR * cornerFactor + 1
        if let glow = style.glow { pad += glow.radius * 1.5 + 2 }
        localBounds = pointBounds.isNull ? .null : pointBounds.insetBy(dx: -pad, dy: -pad)
    }

    /// The outline to fill for variable-width strokes. `radiusScale` thins it
    /// (the neon core); `clip` skips pieces that can't be seen.
    func outline(radiusScale: CGFloat = 1, clip: CGRect? = nil) -> CGPath {
        if let nibVectors {
            let scaled = radiusScale == 1 ? nibVectors
                : nibVectors.map { CGVector(dx: $0.dx * radiusScale, dy: $0.dy * radiusScale) }
            return StrokeOutline.nib(points: points, vectors: scaled, clip: clip)
        }
        let scaled = radiusScale == 1 ? radii : radii.map { $0 * radiusScale }
        return StrokeOutline.capsules(points: points, radii: scaled, clip: clip)
    }

    /// True if `point` (local coordinates) is within `tolerance` of the painted
    /// shape. Glow halos don't count; only the solid stroke is hittable.
    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        guard !points.isEmpty else { return false }
        let widest = isUniform ? style.baseWidth / 2 : (radii.max() ?? 0) * 1.415
        let reach = widest + tolerance
        // Padded by 1pt because `CGRect.contains` excludes the max edges, and a
        // point exactly `reach` away must still hit.
        guard pointBounds.insetBy(dx: -reach - 1, dy: -reach - 1).contains(point) else { return false }
        if points.count == 1 {
            return hypot(point.x - points[0].x, point.y - points[0].y) <= radius(at: 0) + tolerance
        }
        for i in 1..<points.count {
            let r = max(radius(at: i - 1), radius(at: i)) + tolerance
            if PolylineGeometry.distance(from: point, toSegment: points[i - 1], points[i]) <= r {
                return true
            }
        }
        return false
    }

    /// Bounds of the part of the stroke from input sample `control` onward,
    /// plus the last `extraLength` points of arc (where an end taper reshapes
    /// as the stroke grows). Used for minimal live redraws.
    func tailBounds(fromControl control: Int, extraLength: CGFloat) -> CGRect {
        guard !points.isEmpty, let total = arcLengths.last else { return .null }
        // Start tapers rescale with total length while the stroke is short.
        if total < 2 * style.taper.start + 4 { return localBounds }
        let clamped = min(max(control, 0), controlIndices.count - 1)
        var start = controlIndices.isEmpty ? 0 : controlIndices[clamped]
        if extraLength > 0 {
            let cutoff = total - extraLength
            while start > 0, arcLengths[start] > cutoff { start -= 1 }
        }
        let tail = PolylineGeometry.boundingRect(of: Array(points[start...]))
        let pad = localBounds.maxX - pointBounds.maxX
        return tail.insetBy(dx: -pad, dy: -pad)
    }

    private func radius(at i: Int) -> CGFloat {
        if isUniform { return style.baseWidth / 2 }
        if let nibVectors { return max(hypot(nibVectors[i].dx, nibVectors[i].dy), 0.6) }
        return radii[i]
    }

    private static func makeCenterline(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        if points.count == 1 {
            // A click with no drag: a tiny segment so the cap draws a dot.
            path.addLine(to: CGPoint(x: first.x + 0.01, y: first.y))
        } else {
            path.addLines(between: points)
        }
        return path
    }
}
