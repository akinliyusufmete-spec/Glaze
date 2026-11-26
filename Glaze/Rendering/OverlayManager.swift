import AppKit

/// Owns one `OverlayWindow` per connected display and keeps the set in sync
/// with screen changes. Applies modes by flipping click-through on every window
/// and handing the active tool to every canvas.
@MainActor
final class OverlayManager: ModeSink {
    private(set) var windows: [CGDirectDisplayID: OverlayWindow] = [:]
    private let store: CanvasStore
    private let registry: ToolRegistry
    private var currentMode: AppMode = .pointer
    private var currentTool: ToolID = .pen
    // Lives for the app's lifetime (owned by AppEnvironment), so the observer is
    // never removed; the closure holds `self` weakly.
    private var screenObserver: NSObjectProtocol?

    /// Called when Esc is pressed on any canvas.
    var onEscape: (() -> Void)?

    init(store: CanvasStore, registry: ToolRegistry) {
        self.store = store
        self.registry = registry
        store.onChange = { [weak self] id in
            self?.windows[id]?.canvas.canvasDidChange()
        }
        rebuildWindows()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildWindows() }
        }
    }

    func apply(mode: AppMode, previous: AppMode?) {
        currentMode = mode
        if let tool = mode.tool { currentTool = tool }
        for window in windows.values {
            window.canvas.toolID = currentTool
            window.setCapturing(mode.capturesInput)
        }
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// The display the pointer is on, falling back to the main screen.
    func displayUnderMouse() -> CGDirectDisplayID? {
        let location = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) } ?? NSScreen.main
        return screen.flatMap(Self.displayID(of:))
    }

    /// Adds windows for new displays, removes them for unplugged ones and moves
    /// existing ones to their screen's current frame.
    func rebuildWindows() {
        var seen = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            guard let id = Self.displayID(of: screen) else { continue }
            seen.insert(id)
            if let window = windows[id] {
                if window.frame != screen.frame {
                    window.setFrame(screen.frame, display: true)
                }
            } else {
                let window = OverlayWindow(screen: screen, displayID: id, store: store, registry: registry)
                window.canvas.onEscape = { [weak self] in self?.onEscape?() }
                window.canvas.toolID = currentTool
                window.setCapturing(currentMode.capturesInput)
                windows[id] = window
                window.orderFrontRegardless()
            }
        }
        // DECISION: a display's canvas lives in CanvasStore, not in its window, so
        // unplugging a display only closes the window; plugging it back in shows
        // the same drawing (and undo history) again.
        for (id, window) in windows where !seen.contains(id) {
            window.orderOut(nil)
            window.close()
            windows[id] = nil
        }
    }
}
