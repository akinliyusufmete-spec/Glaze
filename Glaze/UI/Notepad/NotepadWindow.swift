import AppKit

/// The notepad's floating panel. It can become key (the text view needs the keyboard) without
/// activating Glaze, and it joins every Space, including full-screen ones.
final class NotepadWindow: NSPanel {
    static let size = NSSize(width: 460, height: 600)

    /// Called when the user presses Escape while the notepad is key.
    var onCancel: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .glazePanel
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true      // drawing and buttons don't take the keyboard; the text view does
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
