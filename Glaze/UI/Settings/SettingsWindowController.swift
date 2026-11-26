import AppKit
import SwiftUI

/// The Settings window. It's a normal titled window (Glaze has no Dock icon, so it activates
/// the app while open) raised above the overlays so it stays clickable in Draw mode.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let makeContent: () -> AnyView
    private let level: () -> NSWindow.Level

    init(level: @escaping () -> NSWindow.Level, content: @escaping () -> AnyView) {
        self.level = level
        self.makeContent = content
    }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: makeContent())
            let window = NSWindow(contentViewController: host)
            window.title = "Glaze Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 620, height: 560))
            window.center()
            self.window = window
        }
        window?.level = level()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func setLevel(_ level: NSWindow.Level) { window?.level = level }
}
