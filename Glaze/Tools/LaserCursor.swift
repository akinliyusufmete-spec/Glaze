import AppKit

/// The laser pointer's cursor: a glowing red dot with a white-hot centre.
@MainActor
enum LaserCursor {
    static func make(color: NSColor = NSColor(srgbRed: 1, green: 0.16, blue: 0.16, alpha: 1)) -> NSCursor {
        let side: CGFloat = 36
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { bounds in
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            if let gradient = NSGradient(colors: [color.withAlphaComponent(0.55), color.withAlphaComponent(0)]) {
                gradient.draw(fromCenter: center, radius: 0, toCenter: center, radius: side / 2, options: [])
            }
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)).fill()
            NSColor(white: 1, alpha: 0.9).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)).fill()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2))
    }
}
