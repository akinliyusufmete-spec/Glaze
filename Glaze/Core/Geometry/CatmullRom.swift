import CoreGraphics
import Foundation

/// Centripetal Catmull-Rom interpolation (Barry–Goldman pyramid). The curve
/// passes through every control point, and the centripetal parameterization
/// never overshoots into cusps or loops on sharp turns.
enum CatmullRom {
    struct Result: Equatable {
        /// Dense samples along the curve.
        var points: [InputPoint]
        /// For each input control point, the index in `points` where it lands.
        /// Duplicate controls map to the same index as their predecessor.
        var controlIndices: [Int]
    }

    /// Interpolates `controls` with output samples at most about `spacing`
    /// points apart. Pressure, tilt and timestamp are interpolated linearly
    /// between neighbouring controls.
    static func interpolate(_ controls: [InputPoint], spacing: CGFloat = 2) -> Result {
        guard !controls.isEmpty else { return Result(points: [], controlIndices: []) }

        // Drop consecutive duplicates (zero-length segments break the knot spacing),
        // remembering where each original control went.
        var unique: [InputPoint] = []
        var uniqueIndexOf: [Int] = []
        for c in controls {
            if let last = unique.last, last.location == c.location {
                uniqueIndexOf.append(unique.count - 1)
            } else {
                unique.append(c)
                uniqueIndexOf.append(unique.count - 1)
            }
        }

        guard unique.count > 1 else {
            return Result(points: [unique[0]], controlIndices: uniqueIndexOf.map { _ in 0 })
        }

        let step = max(spacing, 0.1)
        var out: [InputPoint] = [unique[0]]
        var uniqueToOut: [Int] = [0]
        for i in 0..<(unique.count - 1) {
            let p1 = unique[i]
            let p2 = unique[i + 1]
            let p0 = i > 0 ? unique[i - 1].location : ghost(p1.location, p2.location)
            let p3 = i + 2 < unique.count ? unique[i + 2].location : ghost(p2.location, p1.location)

            let t0: CGFloat = 0
            let t1 = t0 + knot(p0, p1.location)
            let t2 = t1 + knot(p1.location, p2.location)
            let t3 = t2 + knot(p2.location, p3)

            let chord = hypot(p2.location.x - p1.location.x, p2.location.y - p1.location.y)
            let steps = max(1, Int((chord / step).rounded(.up)))
            for s in 1...steps {
                if s == steps {
                    out.append(p2) // exact pass-through
                    break
                }
                let u = CGFloat(s) / CGFloat(steps)
                let t = t1 + (t2 - t1) * u
                let loc = point(at: t, p0, p1.location, p2.location, p3, t0, t1, t2, t3)
                out.append(lerp(p1, p2, u, location: loc))
            }
            uniqueToOut.append(out.count - 1)
        }
        return Result(points: out, controlIndices: uniqueIndexOf.map { uniqueToOut[$0] })
    }

    /// Reflection of `b` through `a`: the phantom control past an endpoint.
    private static func ghost(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: 2 * a.x - b.x, y: 2 * a.y - b.y)
    }

    /// Centripetal knot step: sqrt of the chord length.
    private static func knot(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        max(sqrt(hypot(b.x - a.x, b.y - a.y)), 1e-4)
    }

    private static func mix(_ a: CGPoint, _ b: CGPoint, _ wa: CGFloat, _ wb: CGFloat) -> CGPoint {
        CGPoint(x: a.x * wa + b.x * wb, y: a.y * wa + b.y * wb)
    }

    // swiftlint:disable:next function_parameter_count
    private static func point(
        at t: CGFloat,
        _ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint,
        _ t0: CGFloat, _ t1: CGFloat, _ t2: CGFloat, _ t3: CGFloat
    ) -> CGPoint {
        let a1 = mix(p0, p1, (t1 - t) / (t1 - t0), (t - t0) / (t1 - t0))
        let a2 = mix(p1, p2, (t2 - t) / (t2 - t1), (t - t1) / (t2 - t1))
        let a3 = mix(p2, p3, (t3 - t) / (t3 - t2), (t - t2) / (t3 - t2))
        let b1 = mix(a1, a2, (t2 - t) / (t2 - t0), (t - t0) / (t2 - t0))
        let b2 = mix(a2, a3, (t3 - t) / (t3 - t1), (t - t1) / (t3 - t1))
        return mix(b1, b2, (t2 - t) / (t2 - t1), (t - t1) / (t2 - t1))
    }

    private static func lerp(_ a: InputPoint, _ b: InputPoint, _ u: CGFloat, location: CGPoint) -> InputPoint {
        InputPoint(
            location: location,
            pressure: a.pressure + (b.pressure - a.pressure) * u,
            tilt: CGVector(dx: a.tilt.dx + (b.tilt.dx - a.tilt.dx) * u, dy: a.tilt.dy + (b.tilt.dy - a.tilt.dy) * u),
            timestamp: a.timestamp + (b.timestamp - a.timestamp) * Double(u)
        )
    }
}
