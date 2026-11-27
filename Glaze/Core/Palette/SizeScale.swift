import Foundation

/// Maps a slider position (0…1) to a brush size and back.
// DECISION: logarithmic, so the slider has as much room for 1→2 pt as for 32→64 pt. A linear
// 1…64 slider spends most of its travel on sizes nobody uses and makes thin lines fiddly.
enum SizeScale {
    static let minimum = SizeStepper.minimum
    static let maximum = SizeStepper.maximum

    /// The size at slider position `fraction`, rounded to the nearest half point.
    static func size(forFraction fraction: Double) -> Double {
        let t = min(max(fraction, 0), 1)
        let raw = minimum * pow(maximum / minimum, t)
        return min(max((raw * 2).rounded() / 2, minimum), maximum)
    }

    /// The slider position for `size` (clamped into range).
    static func fraction(forSize size: Double) -> Double {
        let s = min(max(size, minimum), maximum)
        return log(s / minimum) / log(maximum / minimum)
    }
}
