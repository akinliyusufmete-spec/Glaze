import CoreGraphics
import Foundation

/// Pure geometry helpers for polylines. No state, no UI.
enum PolylineGeometry {
    /// Distance from `point` to the segment `a`–`b`. A zero-length segment is a point.
    static func distance(from point: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(point.x - a.x, point.y - a.y) }
        let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared))
        return hypot(point.x - (a.x + t * dx), point.y - (a.y + t * dy))
    }

    /// Shortest distance from `point` to any segment of `polyline`.
    /// `.infinity` for an empty polyline; point distance for a single point.
    static func distance(from point: CGPoint, toPolyline polyline: [CGPoint]) -> CGFloat {
        guard let first = polyline.first else { return .infinity }
        guard polyline.count > 1 else { return hypot(point.x - first.x, point.y - first.y) }
        var best = CGFloat.infinity
        for i in 1..<polyline.count {
            best = min(best, distance(from: point, toSegment: polyline[i - 1], polyline[i]))
        }
        return best
    }

    /// Smallest rect containing every point. `.null` when empty.
    static func boundingRect(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points.dropFirst() {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Evenly spaced points from `a` to `b`, both endpoints included, no two
    /// further apart than `spacing`. Used so a fast eraser drag can't skip strokes.
    static func samples(from a: CGPoint, to b: CGPoint, spacing: CGFloat) -> [CGPoint] {
        let dist = hypot(b.x - a.x, b.y - a.y)
        let steps = max(1, Int((dist / max(spacing, 0.0001)).rounded(.up)))
        return (0...steps).map { i in
            let t = CGFloat(i) / CGFloat(steps)
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }
}

extension PolylineGeometry {
    /// True for a deliberate, nearly straight line: at least 20 pt long and no
    /// point further from the start–end chord than 4 pt or 3% of its length.
    // DECISION: thresholds for the highlighter's auto-straighten, chosen so a
    // hand-drawn underline snaps but a gentle curve doesn't.
    static func isNearlyStraight(_ points: [CGPoint]) -> Bool {
        guard let first = points.first, let last = points.last, points.count > 1 else { return false }
        let chord = hypot(last.x - first.x, last.y - first.y)
        guard chord >= 20 else { return false }
        let limit = max(4, chord * 0.03)
        return points.allSatisfy { distance(from: $0, toSegment: first, last) <= limit }
    }
}
