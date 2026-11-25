import AppKit
import SwiftUI

extension RGBAColor {
    var swiftUIColor: Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }

    /// Converts any `NSColor` (e.g. from `NSColorSampler`) to sRGB components.
    init?(nsColor: NSColor) {
        guard let c = nsColor.usingColorSpace(.sRGB) else { return nil }
        self.init(r: Double(c.redComponent), g: Double(c.greenComponent),
                  b: Double(c.blueComponent), a: Double(c.alphaComponent))
    }
}
