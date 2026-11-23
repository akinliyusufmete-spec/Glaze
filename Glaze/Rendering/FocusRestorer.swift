import AppKit

/// Makes sure that leaving a capture mode never leaves keyboard focus on Glaze.
///
/// The overlays are non-activating panels, so the front app normally never
/// changes. If an overlay did become key while drawing (a later tool asking for
/// keyboard input, or AppKit deciding on its own), this hands key status back to
/// the app that was in front when drawing began.
@MainActor
final class FocusRestorer: ModeSink {
    private var appBeforeCapture: NSRunningApplication?
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    func apply(mode: AppMode, previous: AppMode?) {
        let wasCapturing = previous?.capturesInput ?? false
        if mode.capturesInput, !wasCapturing {
            rememberFrontApp()
        } else if !mode.capturesInput, wasCapturing {
            restore()
        }
    }

    private func rememberFrontApp() {
        let front = NSWorkspace.shared.frontmostApplication
        appBeforeCapture = front?.processIdentifier == ownPID ? nil : front
    }

    private func restore() {
        defer { appBeforeCapture = nil }
        let overlayIsKey = NSApp.windows.contains { $0 is OverlayWindow && $0.isKeyWindow }
        guard overlayIsKey || NSApp.isActive else { return }

        NSApp.keyWindow?.makeFirstResponder(nil)
        NSApp.keyWindow?.resignKey()
        guard let app = appBeforeCapture, !app.isTerminated else { return }
        // DECISION: macOS 14 cooperative activation — yield first, then ask the
        // previous app to activate. Without the yield the request can be ignored.
        NSApp.yieldActivation(to: app)
        app.activate(options: [])
    }
}
