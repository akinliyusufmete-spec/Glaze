import Foundation

/// Nine quick-pick color slots (keys 1–9) with one selected slot.
struct ColorSlots: Equatable, Codable {
    static let defaultColors: [RGBAColor] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#0A84FF", "#AF52DE", "#FF2D55", "#FFFFFF", "#000000",
    ].compactMap { RGBAColor(hex: $0) }

    private(set) var colors: [RGBAColor]
    private(set) var selectedIndex: Int

    init(colors: [RGBAColor] = ColorSlots.defaultColors, selectedIndex: Int = 0) {
        precondition(!colors.isEmpty, "ColorSlots needs at least one slot")
        self.colors = colors
        self.selectedIndex = min(max(selectedIndex, 0), colors.count - 1)
    }

    var count: Int { colors.count }
    var selected: RGBAColor { colors[selectedIndex] }

    mutating func select(_ index: Int) {
        guard colors.indices.contains(index) else { return }
        selectedIndex = index
    }

    mutating func selectNext() { selectedIndex = (selectedIndex + 1) % colors.count }
    mutating func selectPrevious() { selectedIndex = (selectedIndex - 1 + colors.count) % colors.count }

    /// Stores `color` in the selected slot (what picking a color in the panel does).
    mutating func replaceSelected(with color: RGBAColor) { colors[selectedIndex] = color }

    /// Selects the first slot already holding `color` (8-bit match), if any.
    @discardableResult
    mutating func selectSlot(matching color: RGBAColor) -> Bool {
        let key = color.hexString(includeAlpha: true)
        guard let i = colors.firstIndex(where: { $0.hexString(includeAlpha: true) == key }) else { return false }
        selectedIndex = i
        return true
    }
}
