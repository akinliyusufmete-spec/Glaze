import AppKit

/// A transparent, borderless, non-activating panel that covers one display.
///
/// The window is created once per screen and never re-created on a mode change:
/// switching modes only flips `ignoresMouseEvents`, which is what keeps the
/// transition flicker-free.
@MainActor
final class OverlayWindow: NSPanel {
    let displayID: CGDirectDisplayID
    let canvas: CanvasView

    init(screen: NSScreen, displayID: CGDirectDisplayID) {
        self.displayID = displayID
        self.canvas = CanvasView(frame: NSRect(origin: .zero, size: screen.frame.size))
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // DECISION: `.screenSaver` sits above the menu bar, the Dock and full-screen
        // apps' content, but below system alerts. `.statusBar` was too low to draw
        // over the menu bar; anything above `.screenSaver` hides the HUD/alerts.
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        // Only take key status when a view asks for it (CanvasView does so while
        // capturing, so Esc can reach it). In Pointer mode we never become key.
        becomesKeyOnlyIfNeeded = true
        isMovable = false
        animationBehavior = .none
        ignoresMouseEvents = true

        canvas.autoresizingMask = [.width, .height]
        contentView = canvas
        setFrame(screen.frame, display: false)
    }

    // A nonactivating panel can be key without making Glaze the active app,
    // which is how Esc reaches the canvas without changing the front app.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Keep the window glued to its screen even if AppKit tries to constrain it
    /// below the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    func setCapturing(_ capturing: Bool) {
        ignoresMouseEvents = !capturing
        canvas.isCapturing = capturing
    }
}
