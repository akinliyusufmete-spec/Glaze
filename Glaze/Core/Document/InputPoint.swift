import CoreGraphics
import Foundation

/// One sample of pointer input, in canvas (view) coordinates.
struct InputPoint: Equatable, Sendable {
    var location: CGPoint
    /// 0…1. Mice report 1.0.
    var pressure: CGFloat
    /// Pen tilt in -1…1 on each axis; `.zero` for mice.
    var tilt: CGVector
    /// Seconds, on the `NSEvent.timestamp` clock.
    var timestamp: TimeInterval

    init(location: CGPoint, pressure: CGFloat = 1, tilt: CGVector = .zero, timestamp: TimeInterval = 0) {
        self.location = location
        self.pressure = pressure
        self.tilt = tilt
        self.timestamp = timestamp
    }
}
