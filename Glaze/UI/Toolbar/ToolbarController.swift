import AppKit
import SwiftUI

/// Owns the floating toolbar panel: docking it to a screen edge (or leaving it floating),
/// animating it in and out, and handing out its frame so the color panel can attach to it.
/// The panel never activates the app, so clicking it doesn't steal focus from whatever the user
/// is drawing over.
@MainActor
final class ToolbarController {
    private static let originDefaultsKey = "Glaze.toolbarOrigin"

    let state: ToolbarState
    private let entries: [ToolbarEntry]
    private let actions: ToolbarActions
    private let settings: ToolSettings
    private let preferences: Preferences
    private let hints: HintCenter
    private let defaults: UserDefaults
    private let panel = ToolbarPanel()
    private let host = NSHostingView(rootView: AnyView(EmptyView()))

    private var wantsVisible = false
    private var generation = 0
    private var isAnimating = false
    private var screen: NSScreen?

    /// Called whenever the user drags a floating toolbar, so the color panel can follow it.
    var onMove: (() -> Void)?

    init(entries: [ToolbarEntry], actions: ToolbarActions, state: ToolbarState, settings: ToolSettings,
         preferences: Preferences, hints: HintCenter, defaults: UserDefaults = .standard) {
        self.entries = entries
        self.actions = actions
        self.state = state
        self.settings = settings
        self.preferences = preferences
        self.hints = hints
        self.defaults = defaults

        panel.contentView = host
        panel.isMovableByWindowBackground = false     // only the drag handle moves a floating toolbar
        relayout()

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                // Docked toolbars and animations also "move"; only a user drag should be saved.
                guard let self, self.preferences.toolbarPlacement == .floating, !self.isAnimating else { return }
                self.saveOrigin()
                self.onMove?()
            }
        }
    }

    /// Whether the toolbar is (or is animating towards being) on screen.
    var isVisible: Bool { wantsVisible }
    /// Where the toolbar is when shown, used to anchor the color panel.
    var frame: NSRect { shownFrame(size: panel.frame.size) }
    var window: NSWindow { panel }

    func setLevel(_ level: NSWindow.Level) { panel.level = level }

    /// Re-reads the placement preference: rebuilds the view for its orientation, resizes the panel
    /// and, if visible, snaps it to its new position.
    func relayout() {
        host.rootView = AnyView(
            ToolbarView(entries: entries, actions: actions, state: state, settings: settings,
                        placement: preferences.toolbarPlacement)
                .environment(\.hintCenter, hints)
        )
        let size = host.fittingSize
        panel.setContentSize(size)
        if wantsVisible { panel.setFrame(shownFrame(size: size), display: true) }
    }

    func setVisible(_ visible: Bool, animated: Bool) {
        guard visible != wantsVisible || (visible && !panel.isVisible) else { return }
        wantsVisible = visible
        generation += 1
        let current = generation
        hints.cancel()
        if visible { screen = screenUnderMouse() }

        let target = shownFrame(size: panel.frame.size)
        let hidden = preferences.toolbarPlacement.edge.map { DockGeometry.hiddenFrame(from: target, edge: $0) }
        let style = animated ? preferences.animationStyle : .none
        let duration = preferences.animationDuration
        isAnimating = style != .none

        if visible {
            PanelAnimator.show(panel, to: target, from: hidden, style: style, duration: duration) { [weak self] in
                guard let self, self.generation == current else { return }
                self.isAnimating = false
            }
        } else {
            PanelAnimator.hide(panel, to: hidden, style: style, duration: duration) { [weak self] in
                guard let self, self.generation == current else { return }
                self.isAnimating = false
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
            }
        }
    }

    // MARK: Position

    private func shownFrame(size: CGSize) -> NSRect {
        let visible = (screen ?? NSScreen.main)?.visibleFrame ?? NSRect(origin: .zero, size: size)
        if let edge = preferences.toolbarPlacement.edge {
            return DockGeometry.shownFrame(size: size, edge: edge, in: visible)
        }
        return floatingFrame(size: size, visible: visible)
    }

    private func floatingFrame(size: CGSize, visible: NSRect) -> NSRect {
        if let s = defaults.string(forKey: Self.originDefaultsKey) {
            let origin = NSPointFromString(s)
            let probe = NSRect(origin: origin, size: size)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(probe) }) {
                return probe
            }
        }
        return NSRect(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 12,
                      width: size.width, height: size.height)
    }

    private func saveOrigin() {
        defaults.set(NSStringFromPoint(panel.frame.origin), forKey: Self.originDefaultsKey)
    }

    private func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }
}

/// Borderless, non-activating, always-on-top panel.
final class ToolbarPanel: NSPanel {
    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .glazePanel
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// A docked toolbar slides past the screen edge, so AppKit mustn't pull it back.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
