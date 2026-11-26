import AppKit

extension NSWindow.Level {
    /// Glaze's own panels (toolbar, color panel) must sit above the overlay windows,
    /// which use `.screenSaver`, or the overlay would swallow their clicks.
    static let glazePanel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
}
