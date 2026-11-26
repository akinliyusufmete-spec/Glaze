import Foundation
import Observation

/// Editing state for the color panel. HSB is stored (not derived from RGB) so hue and
/// saturation survive passing through black or white while dragging. The colors themselves
/// live in `ToolSettings`; this model is the panel's view of them.
@MainActor
@Observable
final class ColorPanelModel {
    enum Target { case stroke, fill }

    let settings: ToolSettings

    /// Which color the wheel and sliders edit.
    var target: Target = .stroke {
        didSet { if target != oldValue { loadFromTarget() } }
    }

    var hue = 0.0 { didSet { userEdited() } }
    var saturation = 0.0 { didSet { userEdited() } }
    var brightness = 1.0 { didSet { userEdited() } }
    var alpha = 1.0 { didSet { userEdited() } }

    @ObservationIgnored private var isApplying = false

    init(settings: ToolSettings) {
        self.settings = settings
        loadFromTarget()
    }

    var slots: ColorSlots { settings.slots }
    var recents: RecentColors { settings.recents }

    /// The color being edited, as shown by the wheel and sliders.
    var color: RGBAColor {
        RGBAColor(hsb: HSBColor(h: hue, s: saturation, b: brightness), alpha: alpha)
    }

    /// Sets the edited color from outside the sliders (hex field, eyedropper, swatches).
    func apply(_ new: RGBAColor) {
        setHSB(from: new)
        store(new)
    }

    /// Picks slot `index` (also what keys 1–9 do) and edits the stroke color.
    func selectSlot(_ index: Int) {
        settings.selectSlot(index)
        target = .stroke
        loadFromTarget()
    }

    func swapStrokeAndFill() {
        settings.swapStrokeAndFill()
        loadFromTarget()
    }

    /// Re-reads the settings; call after they change from outside (hotkeys, swap).
    func syncFromSettings() { loadFromTarget() }

    /// Records the edited color in the recent list; call when an edit session ends.
    func commit() { settings.commitRecent(color) }

    // MARK: Private

    private func loadFromTarget() {
        setHSB(from: target == .stroke ? settings.strokeColor : settings.fillColor)
    }

    private func store(_ color: RGBAColor) {
        switch target {
        case .stroke: settings.pickStroke(color)
        case .fill: settings.pickFill(color)
        }
    }

    private func setHSB(from c: RGBAColor) {
        isApplying = true
        let hsb = c.hsb
        // Grays and black have no meaningful hue/saturation: keep what the user had.
        if hsb.s > 0, hsb.b > 0 { hue = hsb.h }
        if hsb.b > 0 { saturation = hsb.s }
        brightness = hsb.b
        alpha = Double(c.a)
        isApplying = false
    }

    private func userEdited() {
        guard !isApplying else { return }
        store(color)
    }
}
