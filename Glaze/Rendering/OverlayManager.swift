import AppKit

/// Owns one `OverlayWindow` per connected display and keeps the set in sync
/// with screen changes. Applies modes by flipping click-through on every window.
@MainActor
final class OverlayManager: ModeSink {
    private(set) var windows: [CGDirectDisplayID: OverlayWindow] = [:]
    private var currentMode: AppMode = .pointer
    // Lives for the app's lifetime (owned by AppEnvironment), so the observer is
    // never removed; the closure holds `self` weakly.
    private var screenObserver: NSObjectProtocol?

    /// Called when Esc is pressed on any canvas.
    var onEscape: (() -> Void)?

    init() {
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
        for window in windows.values {
            window.setCapturing(mode.capturesInput)
        }
    }

    func clearAll() {
        windows.values.forEach { $0.canvas.clear() }
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
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
                let window = OverlayWindow(screen: screen, displayID: id)
                window.canvas.onEscape = { [weak self] in self?.onEscape?() }
                window.setCapturing(currentMode.capturesInput)
                windows[id] = window
                window.orderFrontRegardless()
            }
        }
        // DECISION: when a display goes away its drawings go with it. Phase 1 has
        // no document model to migrate strokes into; Phase 2+ may revisit this.
        for (id, window) in windows where !seen.contains(id) {
            window.orderOut(nil)
            window.close()
            windows[id] = nil
        }
    }
}
