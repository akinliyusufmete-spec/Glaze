import CoreGraphics
import Foundation

/// How a stroke thins toward its ends. Lengths are in points of arc length.
struct Taper: Codable, Hashable, Sendable {
    var start: CGFloat
    var end: CGFloat

    init(start: CGFloat = 0, end: CGFloat = 0) {
        self.start = start
        self.end = end
    }

    static let none = Taper()

    /// The narrowest a tapered end gets, as a fraction of full width.
    // DECISION: 15%, so tapered tips stay visibly round instead of vanishing.
    static let minimumScale: CGFloat = 0.15

    /// Width multiplier at arc length `s` along a stroke of total `length`.
    /// Each taper is capped at half the stroke, so short strokes still taper
    /// symmetrically instead of disappearing.
    func scale(at s: CGFloat, length: CGFloat) -> CGFloat {
        guard length >= 2 else { return 1 }
        var result: CGFloat = 1
        let startLength = min(start, length / 2)
        if startLength > 0, s < startLength {
            result = min(result, Self.curve(s / startLength))
        }
        let endLength = min(end, length / 2)
        let fromEnd = length - s
        if endLength > 0, fromEnd < endLength {
            result = min(result, Self.curve(fromEnd / endLength))
        }
        return result
    }

    /// Eases from `minimumScale` at 0 to 1 at 1; the 0.6 power keeps most of
    /// the shrink close to the tip.
    private static func curve(_ x: CGFloat) -> CGFloat {
        max(minimumScale, pow(min(max(x, 0), 1), 0.6))
    }
}
