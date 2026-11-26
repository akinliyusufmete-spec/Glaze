import Foundation

/// Deterministic pseudo-random numbers (splitmix64), so a jittered stroke
/// looks identical every time it's redrawn.
struct SeededNoise: Sendable {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    /// Seeds from a UUID, so each stroke gets its own stable pattern.
    init(uuid: UUID) {
        let b = uuid.uuid
        let hi = [b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        let lo = [b.8, b.9, b.10, b.11, b.12, b.13, b.14, b.15].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        self.init(seed: hi ^ (lo &* 0x9E37_79B9_7F4A_7C15))
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in -1…1.
    mutating func nextUnit() -> CGFloat {
        CGFloat(Double(next() >> 11) / Double(1 << 53)) * 2 - 1
    }
}
