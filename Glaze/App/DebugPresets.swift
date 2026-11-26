#if DEBUG
import AppKit

/// DEBUG-only preset sheet for the Phase 3 check: one row per brush with a
/// mouse-style wave (constant pressure), a pressure ramp (0.1 → 1) and a tilt
/// ramp, so presets, pressure and tilt can be compared in one snapshot.
@MainActor
enum DebugPresets {
    private static let rows: [(ToolID, NSColor)] = [
        (.pen, .systemRed), (.marker, .systemBlue), (.highlighter, .systemYellow),
        (.pencil, .darkGray), (.calligraphy, .black), (.neon, .systemPink), (.dashed, .systemGreen),
    ]

    static func draw(_ store: CanvasStore, display: CanvasStore.DisplayID, size: CGSize) {
        let margin: CGFloat = 60
        let rowHeight = (size.height - 2 * margin) / CGFloat(rows.count)
        let column = (size.width - 2 * margin) / 3
        for (index, (id, color)) in rows.enumerated() {
            guard let style = BrushPresets.preset(for: id) else { continue }
            // Top row first: the canvas is y-up.
            let y = size.height - margin - rowHeight * (CGFloat(index) + 0.5)
            let x0 = margin
            if id == .highlighter {
                // A dark line under the highlighter shows multiply darkening it.
                add(store, display, samples: line(from: x0, to: size.width - margin, y: y),
                    style: BrushPresets.pen, color: .black)
            }
            add(store, display, samples: wave(from: x0, width: column * 0.85, y: y, amplitude: rowHeight * 0.25),
                style: style, color: color)
            var ramp = line(from: x0 + column, to: x0 + column * 1.85, y: y)
            for i in ramp.indices { ramp[i].pressure = 0.1 + 0.9 * CGFloat(i) / CGFloat(ramp.count - 1) }
            add(store, display, samples: ramp, style: style, color: color)
            if id == .calligraphy {
                add(store, display, samples: loop(center: CGPoint(x: x0 + column * 2.45, y: y), radius: rowHeight * 0.3),
                    style: style, color: color)
            } else {
                var tilted = line(from: x0 + column * 2, to: x0 + column * 2.85, y: y)
                for i in tilted.indices {
                    let t = CGFloat(i) / CGFloat(tilted.count - 1)
                    tilted[i].tilt = CGVector(dx: t, dy: 0)
                }
                add(store, display, samples: tilted, style: style, color: color)
            }
        }
    }

    private static func add(
        _ store: CanvasStore, _ display: CanvasStore.DisplayID,
        samples: [InputPoint], style: BrushStyle, color: NSColor
    ) {
        let stroke = StrokeElement(samples: samples, style: style, color: color.cgColor)
        store.perform(AddElement(element: stroke), on: display)
    }

    private static func line(from x0: CGFloat, to x1: CGFloat, y: CGFloat, count: Int = 40) -> [InputPoint] {
        (0..<count).map { i in
            InputPoint(location: CGPoint(x: x0 + (x1 - x0) * CGFloat(i) / CGFloat(count - 1), y: y))
        }
    }

    private static func wave(from x0: CGFloat, width: CGFloat, y: CGFloat, amplitude: CGFloat) -> [InputPoint] {
        (0..<60).map { i in
            let t = CGFloat(i) / 59
            return InputPoint(location: CGPoint(x: x0 + width * t, y: y + amplitude * sin(t * 2 * .pi)))
        }
    }

    private static func loop(center: CGPoint, radius: CGFloat) -> [InputPoint] {
        (0...64).map { i in
            let a = CGFloat(i) / 64 * 2 * .pi
            return InputPoint(location: CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a)))
        }
    }
}
#endif
