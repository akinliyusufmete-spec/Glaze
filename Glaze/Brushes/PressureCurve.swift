import CoreGraphics
import Foundation

/// Maps raw input pressure (0…1) to a width multiplier.
enum PressureCurve: Codable, Hashable, Sendable {
    /// Width ignores pressure.
    case none
    /// Width is proportional to pressure.
    case linear
    /// `pressure ^ exponent`: below 1 is a light response (most of the width
    /// arrives early), above 1 is a strong one (width needs a firm press).
    case ease(exponent: CGFloat)

    /// Even the lightest touch leaves a visible line.
    // DECISION: a 10% floor, so a barely-touching pen still draws.
    static let minimumScale: CGFloat = 0.1

    func scale(for pressure: CGFloat) -> CGFloat {
        let p = min(max(pressure, 0), 1)
        let raw: CGFloat
        switch self {
        case .none: return 1
        case .linear: raw = p
        case .ease(let exponent): raw = pow(p, max(exponent, 0.01))
        }
        return max(Self.minimumScale, raw)
    }
}
