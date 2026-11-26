import Foundation

/// A dotted version like `1.2.3` or `v0.4.0-beta.1`. Pure value type so it is easy to test.
struct SemanticVersion: Comparable, CustomStringConvertible, Sendable {
    let components: [Int]
    /// Text after the first `-` (e.g. `beta.1`); empty for a normal release.
    let prerelease: String

    /// Accepts an optional leading `v`, one to four numeric parts, and an optional `-prerelease`.
    init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.first == "v" || text.first == "V" { text.removeFirst() }
        let halves = text.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let core = halves.first, !core.isEmpty else { return nil }
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(parts.count) else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }), let n = Int(part) else { return nil }
            numbers.append(n)
        }
        components = numbers
        prerelease = halves.count > 1 ? String(halves[1]) : ""
    }

    var description: String {
        components.map(String.init).joined(separator: ".") + (prerelease.isEmpty ? "" : "-\(prerelease)")
    }

    static func == (a: SemanticVersion, b: SemanticVersion) -> Bool {
        !(a < b) && !(b < a)
    }

    static func < (a: SemanticVersion, b: SemanticVersion) -> Bool {
        let count = max(a.components.count, b.components.count)
        for i in 0..<count {
            let x = i < a.components.count ? a.components[i] : 0
            let y = i < b.components.count ? b.components[i] : 0
            if x != y { return x < y }
        }
        // Same numbers: a prerelease sorts before the release it leads up to.
        switch (a.prerelease.isEmpty, b.prerelease.isEmpty) {
        case (true, true): return false
        case (false, true): return true
        case (true, false): return false
        case (false, false): return a.prerelease.compare(b.prerelease, options: .numeric) == .orderedAscending
        }
    }
}
