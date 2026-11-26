import AppKit

extension InputPoint {
    /// The input point for a mouse or tablet event, in `view`'s coordinates.
    /// Tablet events carry pressure and tilt; plain mouse events use the defaults.
    @MainActor
    init(event: NSEvent, in view: NSView) {
        let location = view.convert(event.locationInWindow, from: nil)
        guard event.subtype == .tabletPoint else {
            self.init(location: location, timestamp: event.timestamp)
            return
        }
        self.init(
            location: location,
            pressure: CGFloat(event.pressure),
            tilt: CGVector(dx: event.tilt.x, dy: event.tilt.y),
            timestamp: event.timestamp
        )
    }
}
