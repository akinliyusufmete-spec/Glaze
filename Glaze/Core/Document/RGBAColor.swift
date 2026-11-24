import CoreGraphics
import Foundation

/// A Codable, Sendable sRGB color. `CGColor` is neither, and brush styles and
/// elements need to round-trip through persistence later.
struct RGBAColor: Codable, Hashable, Sendable {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat
    var a: CGFloat

    init(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// Converts any color into sRGB. Unconvertible colors (patterns) become opaque black.
    init(_ color: CGColor) {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        let converted = color.converted(to: srgb, intent: .defaultIntent, options: nil) ?? color
        let c = converted.components ?? []
        switch c.count {
        case 4...: self.init(r: c[0], g: c[1], b: c[2], a: c[3])
        case 2: self.init(r: c[0], g: c[0], b: c[0], a: c[1])
        default: self.init(r: 0, g: 0, b: 0, a: 1)
        }
    }

    var cgColor: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }

    func withAlpha(_ alpha: CGFloat) -> RGBAColor { RGBAColor(r: r, g: g, b: b, a: alpha) }

    static let white = RGBAColor(r: 1, g: 1, b: 1)
    static let black = RGBAColor(r: 0, g: 0, b: 0)
}
