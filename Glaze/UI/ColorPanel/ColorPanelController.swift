import AppKit
import Combine
import SwiftUI

/// Editable color state for the panel. HSB is stored (not derived from RGB) so hue and
/// saturation survive passing through black or white while dragging.
final class ColorPanelModel: ObservableObject {
    @Published var hue: Double { didSet { userEdited() } }
    @Published var saturation: Double { didSet { userEdited() } }
    @Published var brightness: Double { didSet { userEdited() } }
    @Published var alpha: Double { didSet { userEdited() } }
    @Published private(set) var slots: ColorSlots
    @Published private(set) var recents: RecentColors

    /// Fired whenever the color changes, from user edits and from `apply`.
    var onColorChange: ((RGBAColor) -> Void)?

    private var isApplying = false

    init(color: RGBAColor, slots: ColorSlots = ColorSlots(), recents: RecentColors = RecentColors()) {
        let hsb = color.hsb
        hue = hsb.h; saturation = hsb.s; brightness = hsb.b; alpha = color.a
        self.slots = slots
        self.recents = recents
    }

    var color: RGBAColor {
        RGBAColor(hsb: HSBColor(h: hue, s: saturation, b: brightness), alpha: alpha)
    }

    /// Sets the color from outside the sliders (hex field, eyedropper, swatches, app state).
    func apply(_ new: RGBAColor, notify: Bool = true) {
        setHSB(from: new)
        slots.replaceSelected(with: new)
        if notify { onColorChange?(new) }
    }

    func selectSlot(_ index: Int) {
        slots.select(index)
        setHSB(from: slots.selected)
        onColorChange?(slots.selected)
    }

    /// Adds the current color to the recents list; call when an edit session ends.
    func commit() { recents.record(color) }

    private func setHSB(from c: RGBAColor) {
        isApplying = true
        let hsb = c.hsb
        // Grays and black have no meaningful hue/saturation: keep what the user had.
        if hsb.s > 0 && hsb.b > 0 { hue = hsb.h }
        if hsb.b > 0 { saturation = hsb.s }
        brightness = hsb.b
        alpha = c.a
        isApplying = false
    }

    private func userEdited() {
        guard !isApplying else { return }
        slots.replaceSelected(with: color)
        onColorChange?(color)
    }
}

@MainActor
final class ColorPanelController {
    let model: ColorPanelModel
    private let panel: ColorPanelWindow
    private let eyedropper = Eyedropper()
    private weak var previousKeyWindow: NSWindow?

    init(model: ColorPanelModel) {
        self.model = model
        panel = ColorPanelWindow(contentRect: .zero)
        panel.onCancel = { [weak self] in self?.hide() }

        let host = NSHostingView(rootView: ColorPanelView(model: model, onEyedropper: { [weak self] in
            self?.startEyedropper()
        }))
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
    }

    var isVisible: Bool { panel.isVisible }

    /// Shows the panel beside `anchor` (the toolbar's screen frame).
    func show(anchor: NSRect) {
        previousKeyWindow = NSApp.keyWindow.flatMap { $0 === panel ? nil : $0 }
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? anchor
        let frame = PanelPlacement.frame(panelSize: panel.frame.size, anchor: anchor,
                                         visible: visible, preferred: .below)
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
    }

    func hide() {
        model.commit()
        let wasKey = panel.isKeyWindow
        panel.orderOut(nil)
        if wasKey { restoreFocus() }
    }

    func toggle(anchor: NSRect) { isVisible ? hide() : show(anchor: anchor) }

    private func startEyedropper() {
        eyedropper.pick { [weak self] color in
            guard let self else { return }
            if let color { self.model.apply(color); self.model.commit() }
            self.panel.orderFrontRegardless()
            self.restoreFocus()
        }
    }

    private func restoreFocus() {
        // The panel can hold key status while the user types a hex value; give it back to
        // the window that had it so drawing shortcuts keep working.
        if let w = previousKeyWindow, w.isVisible { w.makeKey() }
    }
}
