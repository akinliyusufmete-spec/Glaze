import AppKit
import SwiftUI

/// Owns the notepad panel: showing, hiding, remembering where it was, and handing the keyboard
/// back to the app the user was in. The notepad is independent of Draw mode — it can be opened
/// and closed from Pointer mode with its hotkey.
@MainActor
final class NotepadController {
    private static let originDefaultsKey = "Glaze.notepadOrigin"

    let model: NotepadModel
    private let panel = NotepadWindow()
    private let defaults: UserDefaults
    private var appBeforePad: NSRunningApplication?
    private var observers: [NSObjectProtocol] = []
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    /// Fired when the pad shows or hides.
    var onVisibilityChange: ((Bool) -> Void)?
    /// Fired when the pad gains or loses key status (the keyboard is typing into it).
    var onKeyStatusChange: ((Bool) -> Void)?
    /// Fired when the user drags the pad, so an attached color panel can follow.
    var onMove: (() -> Void)?
    /// Fired when the pad's color swatch is pressed.
    var onColorRequest: (() -> Void)?

    init(model: NotepadModel, settings: ToolSettings, defaults: UserDefaults = .standard) {
        self.model = model
        self.defaults = defaults

        let host = NSHostingView(rootView: NotepadView(
            model: model, settings: settings,
            onClose: { [weak self] in self?.hide() },
            onColor: { [weak self] in self?.onColorRequest?() }
        ))
        host.frame.size = NotepadWindow.size
        panel.contentView = host
        panel.setContentSize(NotepadWindow.size)
        panel.onCancel = { [weak self] in self?.hide() }
        restoreOrigin()

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.saveOrigin()
                self?.onMove?()
            }
        })
        for (name, isKey) in [(NSWindow.didBecomeKeyNotification, true), (NSWindow.didResignKeyNotification, false)] {
            observers.append(center.addObserver(forName: name, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onKeyStatusChange?(isKey) }
            })
        }
        observers.append(center.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.flush() }
        })
    }

    var isVisible: Bool { panel.isVisible }
    var frame: NSRect { panel.frame }

    func setLevel(_ level: NSWindow.Level) { panel.level = level }

    func show() {
        if !panel.isVisible {
            rememberFrontApp()
            panel.orderFrontRegardless()
            onVisibilityChange?(true)
        }
        // Opening the pad to type should let the user type straight away.
        if model.mode == .type { panel.makeKey() }
    }

    func hide() {
        guard panel.isVisible else { return }
        model.flush()
        let hadKeyboard = panel.isKeyWindow
        panel.orderOut(nil)
        if hadKeyboard { giveFocusBack() }
        onVisibilityChange?(false)
    }

    func toggle() { isVisible ? hide() : show() }

    // MARK: Position

    private func saveOrigin() {
        defaults.set(NSStringFromPoint(panel.frame.origin), forKey: Self.originDefaultsKey)
    }

    private func restoreOrigin() {
        if let s = defaults.string(forKey: Self.originDefaultsKey) {
            let origin = NSPointFromString(s)
            let probe = NSRect(origin: origin, size: panel.frame.size)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(probe) }) {
                panel.setFrameOrigin(origin)
                return
            }
        }
        if let visible = NSScreen.main?.visibleFrame {   // default: right side, below the toolbar
            panel.setFrameOrigin(NSPoint(x: visible.maxX - panel.frame.width - 24,
                                         y: visible.maxY - panel.frame.height - 70))
        }
    }

    // MARK: Focus

    private func rememberFrontApp() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ownPID { appBeforePad = front }
    }

    // DECISION: same recipe as `FocusRestorer`: resign key, yield activation, then ask the app that
    // was in front to activate, so closing the pad returns the keyboard to the game or document.
    private func giveFocusBack() {
        panel.makeFirstResponder(nil)
        if panel.isKeyWindow { panel.resignKey() }
        guard NSApp.isActive, let app = appBeforePad, !app.isTerminated else { return }
        NSApp.yieldActivation(to: app)
        app.activate(options: [])
    }
}
