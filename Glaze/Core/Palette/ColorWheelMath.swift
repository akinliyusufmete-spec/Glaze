import CoreGraphics
import Foundation

/// Maps between points on a circular HSB wheel and (hue, saturation).
///
/// Coordinates are the wheel view's own (SwiftUI, y down). Hue 0 is at 3 o'clock and
/// increases clockwise, matching `AngularGradient`'s default. Saturation is the distance
/// from the center as a fraction of `radius`.
enum ColorWheelMath {
    static func hueSaturation(at point: CGPoint, center: CGPoint, radius: CGFloat)
        -> (hue: Double, saturation: Double)
    {
        guard radius > 0 else { return (0, 0) }
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)

        var hue = atan2(dy, dx) / (2 * .pi)
        if hue < 0 { hue += 1 }
        if hue >= 1 { hue = 0 }

        let distance = (dx * dx + dy * dy).squareRoot()
        return (hue, min(distance / Double(radius), 1))
    }

    static func point(hue: Double, saturation: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = hue * 2 * .pi
        let d = min(max(saturation, 0), 1) * Double(radius)
        return CGPoint(x: center.x + CGFloat(cos(angle) * d), y: center.y + CGFloat(sin(angle) * d))
    }
}
