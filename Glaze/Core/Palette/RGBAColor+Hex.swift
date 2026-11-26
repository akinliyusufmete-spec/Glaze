import CoreGraphics
import Foundation

extension RGBAColor {
    /// Parses `#RGB`, `#RGBA`, `#RRGGBB` or `#RRGGBBAA` (leading `#` optional, case-insensitive).
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard !s.isEmpty, s.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }
        if s.count == 3 || s.count == 4 {
            s = s.map { "\($0)\($0)" }.joined()
        }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }

        let hasAlpha = s.count == 8
        let r, g, b, a: UInt64
        if hasAlpha {
            r = (v >> 24) & 0xFF; g = (v >> 16) & 0xFF; b = (v >> 8) & 0xFF; a = v & 0xFF
        } else {
            r = (v >> 16) & 0xFF; g = (v >> 8) & 0xFF; b = v & 0xFF; a = 0xFF
        }
        self.init(r: CGFloat(r) / 255, g: CGFloat(g) / 255, b: CGFloat(b) / 255, a: CGFloat(a) / 255)
    }

    /// Uppercase hex string with leading `#`. Alpha is appended only when requested.
    func hexString(includeAlpha: Bool = false) -> String {
        func byte(_ x: CGFloat) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }
        var out = String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
        if includeAlpha { out += String(format: "%02X", byte(a)) }
        return out
    }
}
