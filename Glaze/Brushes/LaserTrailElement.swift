import CoreGraphics
import Foundation

/// The laser pointer's trail: recent pointer positions, each with an age, drawn so the oldest end
/// is thin and faint and the newest is thick and bright, with a soft red glow and a hot core.
/// Never added to a canvas; the laser tool shows it on the live layer and rebuilds it every frame.
struct LaserTrailElement: Element {
    struct Point: Equatable {
        var location: CGPoint
        /// Seconds since the point was recorded, when this element was built.
        var age: TimeInterval
    }

    let id = UUID()
    /// Oldest first.
    let points: [Point]
    /// Seconds after which a point has fully faded.
    let life: TimeInterval
    let color: CGColor
    /// Width of the newest part of the trail, in points.
    let width: CGFloat

    var transform: CGAffineTransform { .identity }

    static func == (lhs: LaserTrailElement, rhs: LaserTrailElement) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// How visible a point of `age` is: 1 when new, 0 once it has lived `life` seconds.
    static func opacity(forAge age: TimeInterval, life: TimeInterval) -> CGFloat {
        guard life > 0 else { return 0 }
        return CGFloat(min(max(1 - age / life, 0), 1))
    }

    var bounds: CGRect {
        guard let first = points.first else { return .null }
        var rect = CGRect(origin: first.location, size: .zero)
        for p in points.dropFirst() { rect = rect.union(CGRect(origin: p.location, size: .zero)) }
        return rect.insetBy(dx: -width * 4, dy: -width * 4)       // room for the glow
    }

    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> Bool { false }

    func draw(in context: CGContext) {
        guard let last = points.last else { return }
        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)

        for i in 1..<max(points.count, 1) {
            let a = points[i - 1], b = points[i]
            let alpha = Self.opacity(forAge: (a.age + b.age) / 2, life: life)
            guard alpha > 0.01 else { continue }
            let w = width * (0.3 + 0.7 * alpha)

            context.move(to: a.location)
            context.addLine(to: b.location)
            // Glow: wide and faint.
            context.setStrokeColor(color.copy(alpha: alpha * 0.3) ?? color)
            context.setLineWidth(w * 3)
            context.strokePath()

            context.move(to: a.location)
            context.addLine(to: b.location)
            // Body.
            context.setStrokeColor(color.copy(alpha: alpha) ?? color)
            context.setLineWidth(w)
            context.strokePath()

            context.move(to: a.location)
            context.addLine(to: b.location)
            // Hot core.
            context.setStrokeColor(CGColor(srgbRed: 1, green: 0.85, blue: 0.85, alpha: alpha * 0.75))
            context.setLineWidth(max(w * 0.35, 0.8))
            context.strokePath()
        }

        // The dot at the head of the trail, where the pointer is.
        let headAlpha = Self.opacity(forAge: last.age, life: life)
        if headAlpha > 0.01 {
            let r = width * 1.1
            context.setFillColor(color.copy(alpha: headAlpha * 0.35) ?? color)
            context.fillEllipse(in: CGRect(x: last.location.x - r * 2.2, y: last.location.y - r * 2.2,
                                           width: r * 4.4, height: r * 4.4))
            context.setFillColor(color.copy(alpha: headAlpha) ?? color)
            context.fillEllipse(in: CGRect(x: last.location.x - r, y: last.location.y - r, width: r * 2, height: r * 2))
            context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: headAlpha * 0.9))
            context.fillEllipse(in: CGRect(x: last.location.x - r * 0.4, y: last.location.y - r * 0.4,
                                           width: r * 0.8, height: r * 0.8))
        }
        context.restoreGState()
    }
}
