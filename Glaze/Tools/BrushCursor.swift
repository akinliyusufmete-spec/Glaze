import AppKit

/// Builds ring-shaped cursors that preview the brush size.
@MainActor
enum BrushCursor {
    /// A ring of `diameter` points in `color`, with a thin contrasting outline so
    /// it stays visible on both light and dark content. Hotspot is the centre.
    static func make(diameter: CGFloat, color: NSColor) -> NSCursor {
        let ring = max(diameter, 6)
        let side = ceil(ring + 4)
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { bounds in
            let rect = NSRect(
                x: (bounds.width - ring) / 2,
                y: (bounds.height - ring) / 2,
                width: ring,
                height: ring
            )
            let outer = NSBezierPath(ovalIn: rect.insetBy(dx: -0.5, dy: -0.5))
            outer.lineWidth = 3
            NSColor.black.withAlphaComponent(0.55).setStroke()
            outer.stroke()

            let inner = NSBezierPath(ovalIn: rect)
            inner.lineWidth = 1.5
            color.setStroke()
            inner.stroke()

            // Centre dot so tiny brushes still show where the stroke lands.
            let dot = NSRect(x: bounds.midX - 1, y: bounds.midY - 1, width: 2, height: 2)
            NSColor.white.setFill()
            NSBezierPath(ovalIn: dot.insetBy(dx: -0.5, dy: -0.5)).fill()
            color.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2))
    }
}
