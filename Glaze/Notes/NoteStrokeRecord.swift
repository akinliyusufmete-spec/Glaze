import CoreGraphics
import Foundation

/// A `StrokeElement` flattened into plain Codable values so notebook ink can be saved.
/// (`StrokeElement` itself holds a `CGColor`, which isn't Codable.)
struct NoteStrokeRecord: Codable, Equatable {
    struct Sample: Codable, Equatable {
        var x: Double
        var y: Double
        var pressure: Double
        var tiltX: Double
        var tiltY: Double
        var time: Double
    }

    var id: UUID
    var samples: [Sample]
    var style: BrushStyle
    var color: RGBAColor
    /// `CGAffineTransform` as `[a, b, c, d, tx, ty]`.
    var transform: [Double]

    init(_ stroke: StrokeElement) {
        id = stroke.id
        samples = stroke.samples.map {
            Sample(x: Double($0.location.x), y: Double($0.location.y), pressure: Double($0.pressure),
                   tiltX: Double($0.tilt.dx), tiltY: Double($0.tilt.dy), time: $0.timestamp)
        }
        style = stroke.style
        color = RGBAColor(stroke.color)
        let t = stroke.transform
        transform = [t.a, t.b, t.c, t.d, t.tx, t.ty].map(Double.init)
    }

    func makeStroke() -> StrokeElement {
        let points = samples.map {
            InputPoint(location: CGPoint(x: $0.x, y: $0.y), pressure: CGFloat($0.pressure),
                       tilt: CGVector(dx: $0.tiltX, dy: $0.tiltY), timestamp: $0.time)
        }
        let t = transform.count == 6 ? transform.map { CGFloat($0) } : [1, 0, 0, 1, 0, 0]
        return StrokeElement(
            id: id, samples: points, style: style, color: color.cgColor,
            transform: CGAffineTransform(a: t[0], b: t[1], c: t[2], d: t[3], tx: t[4], ty: t[5])
        )
    }
}
