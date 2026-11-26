import CoreGraphics
import Foundation
import Observation

/// What the user has chosen for drawing: stroke and fill colors, the nine color slots,
/// recent colors and per-brush widths. Tools read it when a stroke begins; the toolbar and
/// color panel write it. Persisted in UserDefaults.
// DECISION: one stroke color for every brush (picked from the slots) rather than one per
// brush; the highlighter's translucency comes from its `BrushStyle`, not from a special color.
@MainActor
@Observable
final class ToolSettings {
    private enum Key {
        static let slots = "palette.slots"
        static let recents = "palette.recents"
        static let fill = "palette.fill"
        static let widths = "tool.widths"
        static let laserFade = "tool.laserFade"
    }

    /// The color strokes are drawn with. Always the selected slot's color.
    var strokeColor: RGBAColor { slots.selected }
    private(set) var fillColor: RGBAColor
    private(set) var slots: ColorSlots
    private(set) var recents: RecentColors
    /// Width overrides in points; a tool with no entry uses its preset's `baseWidth`.
    private(set) var widths: [ToolID: CGFloat]

    /// Seconds the laser pointer's trail takes to fade once the pointer stops.
    private(set) var laserFadeDuration: TimeInterval

    static let laserFadeRange: ClosedRange<Double> = 0.2...3

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        slots = Self.load(ColorSlots.self, Key.slots, from: defaults) ?? ColorSlots()
        recents = Self.load(RecentColors.self, Key.recents, from: defaults) ?? RecentColors()
        fillColor = Self.load(RGBAColor.self, Key.fill, from: defaults) ?? RGBAColor(hex: "#0A84FF") ?? .black
        let stored = Self.load([String: Double].self, Key.widths, from: defaults) ?? [:]
        widths = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in
            ToolID(rawValue: key).map { ($0, CGFloat(value)) }
        })
        laserFadeDuration = Self.laserFadeRange.clamp(
            Self.load(Double.self, Key.laserFade, from: defaults) ?? BrushPresets.laser.fadeDuration ?? 0.8)
    }

    // MARK: Colors

    /// Sets the stroke color by replacing the selected slot's color.
    func pickStroke(_ color: RGBAColor) {
        slots.replaceSelected(with: color)
        save(slots, Key.slots)
    }

    func pickFill(_ color: RGBAColor) {
        fillColor = color
        save(fillColor, Key.fill)
    }

    /// The ⇄ button: stroke becomes fill and fill becomes stroke.
    func swapStrokeAndFill() {
        let oldStroke = strokeColor
        pickStroke(fillColor)
        pickFill(oldStroke)
    }

    /// Keys 1–9. Out-of-range indexes are ignored.
    func selectSlot(_ index: Int) {
        guard slots.colors.indices.contains(index) else { return }
        slots.select(index)
        save(slots, Key.slots)
    }

    /// Adds a color to the recent list (call when an edit finishes, not on every drag step).
    func commitRecent(_ color: RGBAColor) {
        recents.record(color)
        save(recents, Key.recents)
    }

    func setLaserFadeDuration(_ seconds: TimeInterval) {
        laserFadeDuration = Self.laserFadeRange.clamp(seconds)
        save(laserFadeDuration, Key.laserFade)
    }

    // MARK: Widths

    func width(for tool: ToolID) -> CGFloat? { widths[tool] }

    /// The width a tool has before the user changes it: the brush preset's, or the eraser's diameter.
    /// `nil` for tools with no size (the laser, shapes yet to come).
    static func presetWidth(for tool: ToolID) -> CGFloat? {
        if tool == .eraser { return EraserTool.defaultDiameter }
        guard let style = BrushPresets.preset(for: tool), !style.isTransient else { return nil }
        return style.baseWidth
    }

    /// The width a tool draws with now: the user's choice, else the preset.
    func effectiveWidth(for tool: ToolID) -> CGFloat? { widths[tool] ?? Self.presetWidth(for: tool) }

    func setWidth(_ width: CGFloat, for tool: ToolID) {
        widths[tool] = SizeStepper.clamped(Double(width)).cgFloat
        save(Dictionary(uniqueKeysWithValues: widths.map { ($0.key.rawValue, Double($0.value)) }), Key.widths)
    }

    /// Steps `tool`'s width one rung up or down `SizeStepper.ladder`.
    /// `presetWidth` is used as the starting point when the tool has no override yet.
    @discardableResult
    func stepWidth(for tool: ToolID, presetWidth: CGFloat, up: Bool) -> CGFloat {
        let current = Double(widths[tool] ?? presetWidth)
        let next = up ? SizeStepper.increased(current) : SizeStepper.decreased(current)
        setWidth(CGFloat(next), for: tool)
        return CGFloat(next)
    }

    // MARK: Persistence

    private func save(_ value: some Encodable, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String, from defaults: UserDefaults) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}

private extension Double {
    var cgFloat: CGFloat { CGFloat(self) }
}
