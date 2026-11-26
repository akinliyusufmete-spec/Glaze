import AppKit
import SwiftUI

@MainActor
final class ColorPanelController {
    let model: ColorPanelModel
    private let panel: ColorPanelWindow
    private let eyedropper = Eyedropper()
    private var appBeforePanel: NSRunningApplication?
    private var observers: [NSObjectProtocol] = []
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    /// Fired when the panel shows or hides.
    var onVisibilityChange: ((Bool) -> Void)?
    /// Fired when the panel gains or loses key status (i.e. while the hex field has the keyboard).
    var onKeyStatusChange: ((Bool) -> Void)?

    init(model: ColorPanelModel) {
        self.model = model
        panel = ColorPanelWindow(contentRect: .zero)
        panel.onCancel = { [weak self] in self?.hide() }

        let host = NSHostingView(rootView: ColorPanelView(
            model: model,
            onEyedropper: { [weak self] in self?.pickFromScreen() },
            onFinishedTyping: { [weak self] in self?.releaseKeyboard() }
        ))
        panel.contentView = host
        panel.setContentSize(host.fittingSize)

        for (name, isKey) in [(NSWindow.didBecomeKeyNotification, true), (NSWindow.didResignKeyNotification, false)] {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: panel, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.onKeyStatusChange?(isKey) }
            })
        }
    }

    var isVisible: Bool { panel.isVisible }

    /// Shows the panel next to `anchor` (the toolbar's screen frame).
    func show(anchor: NSRect, preferred: PanelPlacement.Side = .below) {
        if !panel.isVisible { rememberFrontApp() }
        place(anchor: anchor, preferred: preferred)
        panel.orderFrontRegardless()
        onVisibilityChange?(true)
    }

    /// Moves a visible panel to follow its anchor.
    func place(anchor: NSRect, preferred: PanelPlacement.Side = .below) {
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let frame = PanelPlacement.frame(panelSize: panel.frame.size, anchor: anchor,
                                         visible: screen?.visibleFrame ?? anchor, preferred: preferred)
        panel.setFrame(frame, display: false)
    }

    func hide() {
        guard panel.isVisible else { return }
        model.commit()
        let hadKeyboard = panel.isKeyWindow
        panel.orderOut(nil)
        if hadKeyboard { giveFocusBack() }
        onVisibilityChange?(false)
    }

    func setLevel(_ level: NSWindow.Level) { panel.level = level }

    func toggle(anchor: NSRect, preferred: PanelPlacement.Side = .below) {
        isVisible ? hide() : show(anchor: anchor, preferred: preferred)
    }

    /// Samples a pixel from anywhere on screen (any app); the result becomes the edited color.
    func pickFromScreen() {
        rememberFrontApp()
        eyedropper.pick { [weak self] color in
            guard let self else { return }
            if let color {
                self.model.apply(color)
                self.model.commit()
            }
            self.giveFocusBack()
        }
    }

    /// Lets go of the keyboard after typing a hex value so the single-key shortcuts work again.
    func releaseKeyboard() {
        if panel.isKeyWindow { giveFocusBack() }
    }

    // MARK: Focus

    private func rememberFrontApp() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ownPID { appBeforePanel = front }
    }

    // DECISION: same recipe as `FocusRestorer`: resign key, yield activation, then ask the
    // app that was in front to activate. Without the yield macOS 14 can ignore the request.
    private func giveFocusBack() {
        panel.makeFirstResponder(nil)
        if panel.isKeyWindow { panel.resignKey() }
        guard NSApp.isActive, let app = appBeforePanel, !app.isTerminated else { return }
        NSApp.yieldActivation(to: app)
        app.activate(options: [])
    }
}
