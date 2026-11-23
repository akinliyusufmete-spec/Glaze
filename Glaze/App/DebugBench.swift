#if DEBUG
import AppKit
import QuartzCore

/// DEBUG-only rendering benchmark for the Phase 2 check: "300 strokes keep
/// drawing at full frame rate". Drives a canvas through synthetic input (no
/// Accessibility needed) and logs timings with NSLog.
@MainActor
enum DebugBench {
    /// Adds `count` random strokes to `display`, each one undoable `AddElement`.
    static func stress(_ store: CanvasStore, display: CanvasStore.DisplayID, size: CGSize, count: Int = 300) {
        var rng = SystemRandomNumberGenerator()
        let colors: [NSColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple]
        for i in 0..<count {
            var point = CGPoint(
                x: .random(in: 40...(size.width - 40), using: &rng),
                y: .random(in: 40...(size.height - 40), using: &rng)
            )
            var points = [point]
            for _ in 0..<Int.random(in: 20...80, using: &rng) {
                point.x = min(max(point.x + .random(in: -14...14, using: &rng), 0), size.width)
                point.y = min(max(point.y + .random(in: -14...14, using: &rng), 0), size.height)
                points.append(point)
            }
            let stroke = StrokeElement(points: points, color: colors[i % colors.count].cgColor, width: .random(in: 2...8, using: &rng))
            store.perform(AddElement(element: stroke), on: display)
        }
    }

    /// Times a full committed render, one live stroke (per-event cost) and the
    /// incremental commit/undo renders on `canvas`.
    static func run(on canvas: CanvasView, store: CanvasStore) {
        canvas.debugFlush()
        let elements = canvas.canvas.elements.count

        var full: [Double] = []
        for _ in 0..<5 {
            full.append(time { canvas.debugForceFullRender() })
        }

        // A 500-event spiral, flushed after every event as a frame would be.
        let center = CGPoint(x: canvas.bounds.midX, y: canvas.bounds.midY)
        var perEvent: [Double] = []
        canvas.debugInput(.begin, at: center)
        canvas.debugFlush()
        for i in 1..<500 {
            let angle = Double(i) * 0.06
            let radius = Double(i) * 0.6
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            perEvent.append(time {
                canvas.debugInput(.move, at: point)
                canvas.debugFlush()
            })
        }
        let commit = time {
            canvas.debugInput(.end, at: CGPoint(x: center.x + 300, y: center.y))
            canvas.debugFlush()
        }
        let undo = time {
            store.undo(on: canvas.displayID)
            canvas.debugFlush()
        }

        let sorted = perEvent.sorted()
        let avg = perEvent.reduce(0, +) / Double(perEvent.count)
        let p95 = sorted[Int(Double(sorted.count) * 0.95)]
        NSLog("%@", "GLAZE-DEBUG [bench] elements=\(elements) size=\(Int(canvas.bounds.width))x\(Int(canvas.bounds.height))"
            + " scale=\(canvas.window?.backingScaleFactor ?? 0)")
        NSLog("%@", "GLAZE-DEBUG [bench] fullRender avg=\(fmt(full.reduce(0, +) / 5))ms max=\(fmt(full.max() ?? 0))ms")
        NSLog("%@", "GLAZE-DEBUG [bench] liveEvent avg=\(fmt(avg))ms p95=\(fmt(p95))ms max=\(fmt(sorted.last ?? 0))ms (budget 8.3ms @120Hz)")
        NSLog("%@", "GLAZE-DEBUG [bench] commit=\(fmt(commit))ms undo=\(fmt(undo))ms")
    }

    /// Writes `base` (the committed bitmap) with `live` drawn on top, over white, as a PNG.
    static func writePNG(base: CGImage, live: (any Element)?, scale: CGFloat, to url: URL) -> Bool {
        let rect = CGRect(x: 0, y: 0, width: base.width, height: base.height)
        let space = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: base.width, height: base.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(rect)
        ctx.draw(base, in: rect)
        ctx.scaleBy(x: scale, y: scale)
        live?.draw(in: ctx)
        guard let image = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
        else { return false }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest)
    }

    private static func time(_ body: () -> Void) -> Double {
        let start = CACurrentMediaTime()
        body()
        return (CACurrentMediaTime() - start) * 1000
    }

    private static func fmt(_ ms: Double) -> String { String(format: "%.2f", ms) }
}
#endif
