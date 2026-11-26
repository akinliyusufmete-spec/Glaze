import AppKit

/// Decides when the toolbar and its edge handle are on screen, from the app mode and the
/// "how should the toolbar appear" preference:
///
/// - **Always**: visible whenever Draw mode is on (and the "show toolbar" preference allows it).
/// - **Keybind**: hidden until the toolbar shortcut is pressed; then pinned, in any mode.
/// - **Edge**: while drawing, only a small handle shows on the screen edge; tapping it brings the
///   toolbar out, and it tucks away again once the pointer has stayed away for the auto-hide delay.
@MainActor
final class DockCoordinator: ModeSink {
    private let toolbar: ToolbarController
    private let handle: EdgeHandleController
    private let state: ToolbarState
    private let preferences: Preferences

    /// Frames (screen coordinates) that keep an auto-hiding toolbar open while the pointer is
    /// over them: the color panel attached to it.
    var keepOpenRegions: () -> [NSRect] = { [] }
    /// Called when the toolbar goes away, so the color panel attached to it can go too.
    var onToolbarHidden: () -> Void = {}

    private var mode: AppMode = .pointer
    private var pinned = false              // keybind mode
    private var edgeRevealed = false         // edge mode
    private var lastNear = Date()
    private var timer: Timer?

    init(toolbar: ToolbarController, handle: EdgeHandleController, state: ToolbarState, preferences: Preferences) {
        self.toolbar = toolbar
        self.handle = handle
        self.state = state
        self.preferences = preferences
        handle.onTap = { [weak self] in self?.revealFromHandle() }
    }

    // MARK: ModeSink

    func apply(mode: AppMode, previous: AppMode?) {
        if case .momentaryDraw = mode { return }    // a held-key stroke shouldn't flash the panels
        self.mode = mode
        state.selectedToolID = mode.tool?.rawValue
        if mode.tool == nil { edgeRevealed = false }
        update(animated: previous != nil)
    }

    // MARK: Commands

    /// The toolbar shortcut and the menu item.
    func toggle() {
        switch preferences.toolbarReveal {
        case .always: preferences.showToolbar.toggle()      // fires `onChange`, which calls `reconfigure`
        case .keybind: pinned.toggle()
        case .edge: edgeRevealed.toggle()
        }
        update(animated: true)
    }

    /// Brings the toolbar out if it is hidden, in whatever way the current reveal mode allows.
    /// Used when something that hangs off the toolbar (the color panel) needs it on screen.
    func reveal() {
        guard mode.tool != nil || preferences.toolbarReveal == .keybind else { return }
        switch preferences.toolbarReveal {
        case .always: if !preferences.showToolbar { preferences.showToolbar = true }
        case .keybind: pinned = true
        case .edge: edgeRevealed = true
        }
        update(animated: true)
    }

    /// After a preference changes: re-lay-out both windows, then re-evaluate what should show.
    func reconfigure() {
        toolbar.relayout()
        handle.relayout()
        update(animated: true)
    }

    /// Settings → Animation → Preview: plays the hide and show animations once.
    func preview() {
        let wasVisible = toolbar.isVisible
        // Flip it, then put it back to what the settings say it should be. A hidden toolbar gets a
        // longer look before it goes away again.
        let delay = preferences.animationDuration + (wasVisible ? 0.35 : 0.9)
        toolbar.setVisible(!wasVisible, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            MainActor.assumeIsolated { self?.update(animated: true) }
        }
    }

    // MARK: Private

    private func update(animated: Bool) {
        let drawing = mode.tool != nil
        let wantToolbar: Bool
        let wantHandle: Bool
        switch preferences.toolbarReveal {
        case .always:
            wantToolbar = drawing && preferences.showToolbar
            wantHandle = false
        case .keybind:
            wantToolbar = pinned
            wantHandle = false
        case .edge:
            wantToolbar = drawing && edgeRevealed
            wantHandle = drawing && !edgeRevealed
        }
        toolbar.setVisible(wantToolbar, animated: animated)
        handle.setVisible(wantHandle, animated: animated)
        if !wantToolbar { onToolbarHidden() }
        setAutoHide(active: wantToolbar && preferences.toolbarReveal == .edge)
    }

    private func revealFromHandle() {
        edgeRevealed = true
        update(animated: true)
    }

    private func setAutoHide(active: Bool) {
        guard active else {
            timer?.invalidate()
            timer = nil
            return
        }
        guard timer == nil else { return }
        lastNear = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        let mouse = NSEvent.mouseLocation
        let regions = [toolbar.frame.insetBy(dx: -10, dy: -10)] + keepOpenRegions()
        // Dragging the size slider counts as "near" even if the pointer strays off the toolbar.
        if NSEvent.pressedMouseButtons != 0 || regions.contains(where: { $0.contains(mouse) }) {
            lastNear = Date()
            return
        }
        if Date().timeIntervalSince(lastNear) >= preferences.autoHideDelay {
            edgeRevealed = false
            update(animated: true)
        }
    }
}
