import AppKit
import SwiftUI

/// Owns the floating toolbar panel. The panel never activates the app, so clicking it
/// doesn't steal focus from whatever the user is drawing over.
@MainActor
final class ToolbarController {
    private static let originDefaultsKey = "Glaze.toolbarOrigin"

    let state: ToolbarState
    private let panel: ToolbarPanel
    private let defaults: UserDefaults

    /// Called whenever the user drags the toolbar, so the color panel can follow it.
    var onMove: (() -> Void)?

    init(entries: [ToolbarEntry], actions: ToolbarActions, state: ToolbarState, settings: ToolSettings,
         defaults: UserDefaults = .standard) {
        self.state = state
        self.defaults = defaults

        let host = NSHostingView(rootView: ToolbarView(entries: entries, actions: actions, state: state, settings: settings))
        host.frame.size = host.fittingSize

        panel = ToolbarPanel(contentRect: NSRect(origin: .zero, size: host.fittingSize))
        panel.contentView = host
        panel.isMovableByWindowBackground = false     // the drag handle moves it
        restoreOrigin()

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.saveOrigin()
                self?.onMove?()
            }
        }
    }

    var isVisible: Bool { panel.isVisible }
    /// Screen frame, used to anchor the color panel.
    var frame: NSRect { panel.frame }
    var window: NSWindow { panel }

    func show() { panel.orderFrontRegardless() }
    func hide() { panel.orderOut(nil) }
    func toggle() { isVisible ? hide() : show() }

    // MARK: Position persistence

    private func saveOrigin() {
        defaults.set(NSStringFromPoint(panel.frame.origin), forKey: Self.originDefaultsKey)
    }

    private func restoreOrigin() {
        if let s = defaults.string(forKey: Self.originDefaultsKey) {
            let p = NSPointFromString(s)
            let probe = NSRect(origin: p, size: panel.frame.size)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(probe) }) {
                panel.setFrameOrigin(p)
                return
            }
        }
        // Default: top-center of the main screen.
        if let vf = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: vf.midX - panel.frame.width / 2,
                                         y: vf.maxY - panel.frame.height - 12))
        }
    }
}

/// Borderless, non-activating, always-on-top panel.
final class ToolbarPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .glazePanel
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
