import CoreGraphics
import Foundation

/// A blurred halo in the stroke color with a bright inner core (neon, laser).
struct Glow: Codable, Hashable, Sendable {
    /// Blur radius in points.
    var radius: CGFloat
    /// The thin line drawn on top of the blurred stroke.
    var coreColor: RGBAColor

    init(radius: CGFloat, coreColor: RGBAColor = .white) {
        self.radius = radius
        self.coreColor = coreColor
    }

    /// Core width as a fraction of the stroke width.
    // DECISION: 40% reads as a hot filament inside a colored tube.
    static let coreWidthFraction: CGFloat = 0.4
}
