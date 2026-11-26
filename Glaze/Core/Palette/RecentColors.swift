import Foundation

/// Most-recently-used colors, newest first, de-duplicated at 8-bit precision.
struct RecentColors: Equatable, Codable {
    static let defaultCapacity = 12

    private(set) var colors: [RGBAColor]
    let capacity: Int

    init(colors: [RGBAColor] = [], capacity: Int = RecentColors.defaultCapacity) {
        self.capacity = max(1, capacity)
        self.colors = []
        // Insert oldest-first so the given array's first element ends up newest.
        for color in colors.reversed() { record(color) }
    }

    mutating func record(_ color: RGBAColor) {
        let key = color.hexString(includeAlpha: true)
        colors.removeAll { $0.hexString(includeAlpha: true) == key }
        colors.insert(color, at: 0)
        if colors.count > capacity { colors.removeLast(colors.count - capacity) }
    }

    mutating func clear() { colors.removeAll() }
}
