import Foundation

/// Steps a brush size up or down through a fixed ladder of sizes (in points).
enum SizeStepper {
    static let ladder: [Double] = [1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64]

    static var minimum: Double { ladder.first! }
    static var maximum: Double { ladder.last! }

    /// The next ladder value strictly greater than `size`, or the maximum.
    static func increased(_ size: Double) -> Double {
        ladder.first { $0 > size } ?? maximum
    }

    /// The next ladder value strictly smaller than `size`, or the minimum.
    static func decreased(_ size: Double) -> Double {
        ladder.last { $0 < size } ?? minimum
    }

    static func clamped(_ size: Double) -> Double {
        min(max(size, minimum), maximum)
    }
}
