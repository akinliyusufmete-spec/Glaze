import CoreGraphics
import Foundation

/// Anything that lives on a canvas: strokes now, shapes/images/text later.
///
/// Elements are immutable values; changing one means a `Command` replaces it,
/// which keeps undo trivial.
protocol Element: Identifiable, Hashable {
    var id: UUID { get }
    /// Bounding box in canvas coordinates, including stroke width and transform.
    var bounds: CGRect { get }
    var transform: CGAffineTransform { get }
    func draw(in context: CGContext)
    /// True if `point` (canvas coordinates) is within `tolerance` of the element.
    func hitTest(_ point: CGPoint, tolerance: CGFloat) -> Bool
    /// How the element composites onto what's below it. Layers that draw
    /// elements into separate surfaces use this to match the final result.
    var blendMode: CGBlendMode { get }
}

extension Element {
    var blendMode: CGBlendMode { .normal }
}
