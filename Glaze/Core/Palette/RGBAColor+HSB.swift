import CoreGraphics
import Foundation

/// Hue, saturation and brightness, each in 0...1 (hue wraps).
struct HSBColor: Equatable {
    var h: Double
    var s: Double
    var b: Double
}

extension RGBAColor {
    var hsb: HSBColor {
        let r = Double(self.r), g = Double(self.g), b = Double(self.b)
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC

        var hue = 0.0
        if delta > 0 {
            if maxC == r {
                hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxC == g {
                hue = (b - r) / delta + 2
            } else {
                hue = (r - g) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        let sat = maxC > 0 ? delta / maxC : 0
        return HSBColor(h: hue, s: sat, b: maxC)
    }

    init(hsb: HSBColor, alpha: Double = 1) {
        let h = hsb.h - hsb.h.rounded(.down)          // wrap into 0..<1
        let s = min(max(hsb.s, 0), 1)
        let v = min(max(hsb.b, 0), 1)

        let c = v * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c

        let (r1, g1, b1): (Double, Double, Double)
        switch Int(h * 6) {
        case 0: (r1, g1, b1) = (c, x, 0)
        case 1: (r1, g1, b1) = (x, c, 0)
        case 2: (r1, g1, b1) = (0, c, x)
        case 3: (r1, g1, b1) = (0, x, c)
        case 4: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        self.init(r: CGFloat(r1 + m), g: CGFloat(g1 + m), b: CGFloat(b1 + m), a: CGFloat(alpha))
    }
}
