import AppKit
import CoreGraphics

/// The window levels Glaze's windows use, as one decision in one place.
///
/// By default everything sits at `.screenSaver` (overlays) and one above (panels, HUD). That is
/// enough to draw over native full-screen apps, full-screen browser tabs and borderless-window
/// games, because the windows also join every Space (`.canJoinAllSpaces` + `.fullScreenAuxiliary`).
///
/// Games that take over the display exclusively (`CGDisplayCapture`) hide ordinary windows. Those
/// only show windows at or above `CGShieldingWindowLevel()`, so an opt-in mode raises everything
/// to that level. It also puts Glaze above system alerts, which is why it isn't the default.
struct WindowLevels: Equatable {
    let overlay: NSWindow.Level
    let panel: NSWindow.Level

    init(coverFullScreenGames: Bool) {
        let base = coverFullScreenGames
            ? Int(CGShieldingWindowLevel()) + 1
            : NSWindow.Level.screenSaver.rawValue
        overlay = NSWindow.Level(rawValue: base)
        panel = NSWindow.Level(rawValue: base + 1)
    }
}
