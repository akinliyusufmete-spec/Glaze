import CoreGraphics
import Foundation

/// How a brush reacts to pen tilt. Mice and trackpads report zero tilt, so
/// every case leaves mouse strokes unchanged.
// DECISION: the spec names tilt as an input but not what it does per brush.
// Pencil widens when tilted (shading with the side of the lead); calligraphy
// turns its nib toward the tilt direction.
enum TiltResponse: Codable, Hashable, Sendable {
    case none
    /// Width grows by up to `factor` × at full tilt.
    case widen(factor: CGFloat)
    /// The nib angle follows the tilt direction when the pen is tilted enough.
    case rotateNib

    /// Tilt magnitude below which `rotateNib` keeps the preset angle; small
    /// tilts are noisy and would make the nib wobble.
    static let rotateThreshold: CGFloat = 0.15

    func widthScale(for tilt: CGVector) -> CGFloat {
        guard case .widen(let factor) = self else { return 1 }
        return 1 + factor * min(1, hypot(tilt.dx, tilt.dy))
    }

    /// The nib angle to use for a sample, given the brush's own angle.
    func nibAngle(base: CGFloat, tilt: CGVector) -> CGFloat {
        guard case .rotateNib = self, hypot(tilt.dx, tilt.dy) > Self.rotateThreshold else { return base }
        return atan2(tilt.dy, tilt.dx) + .pi / 2
    }
}
