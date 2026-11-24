import CoreGraphics
import Foundation

/// The One-Euro filter (Casiez et al. 2012) applied to 2D pointer positions:
/// heavy smoothing when the pointer is slow (where jitter is visible), light
/// smoothing when it is fast (where lag is visible).
///
/// DECISION: the spec's single "StrokeSmoother" is split into this filter
/// (noise removal at input time) and `CatmullRom` (curve reconstruction at
/// render time), so each part is small and tested on its own.
///
/// DECISION: macOS has no coalesced-event API like iOS, so every mouse/tablet
/// event that AppKit delivers is fed here; there is nothing extra to unpack.
struct OneEuroFilter: Sendable {
    /// Cutoff (Hz) at zero speed. Lower = smoother but laggier when slow.
    var minCutoff: Double = 3
    /// How fast the cutoff rises with speed (per pt/s).
    var beta: Double = 0.02
    /// Cutoff (Hz) for the speed estimate itself.
    var dCutoff: Double = 1

    private var last: InputPoint?
    private var lastSpeed: Double = 0

    init(minCutoff: Double = 3, beta: Double = 0.02, dCutoff: Double = 1) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    mutating func reset() {
        last = nil
        lastSpeed = 0
    }

    /// Filters one sample. Only the location is smoothed; pressure, tilt and
    /// timestamp pass through unchanged. The first sample passes through exactly.
    mutating func filter(_ point: InputPoint) -> InputPoint {
        guard let previous = last else {
            last = point
            return point
        }
        var dt = point.timestamp - previous.timestamp
        // DECISION: synthetic or out-of-order events with no usable time delta
        // are assumed to be one 120 Hz frame apart.
        if dt <= 0 { dt = 1.0 / 120 }
        let rate = 1 / dt

        let dx = Double(point.location.x - previous.location.x)
        let dy = Double(point.location.y - previous.location.y)
        let speed = (dx * dx + dy * dy).squareRoot() * rate
        let smoothedSpeed = lastSpeed + Self.alpha(rate: rate, cutoff: dCutoff) * (speed - lastSpeed)

        let cutoff = minCutoff + beta * smoothedSpeed
        let a = CGFloat(Self.alpha(rate: rate, cutoff: cutoff))
        var out = point
        out.location = CGPoint(
            x: previous.location.x + a * (point.location.x - previous.location.x),
            y: previous.location.y + a * (point.location.y - previous.location.y)
        )
        last = out
        lastSpeed = smoothedSpeed
        return out
    }

    /// Filters a whole sequence with a fresh filter.
    static func filter(all points: [InputPoint], minCutoff: Double = 3, beta: Double = 0.02) -> [InputPoint] {
        var f = OneEuroFilter(minCutoff: minCutoff, beta: beta)
        return points.map { f.filter($0) }
    }

    private static func alpha(rate: Double, cutoff: Double) -> Double {
        1 / (1 + rate / (2 * .pi * cutoff))
    }
}
