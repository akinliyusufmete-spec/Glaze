import XCTest
import AppKit
@testable import Glaze

final class WindowLevelsTests: XCTestCase {
    func testDefaultKeepsTheOriginalLevels() {
        let l = WindowLevels(coverFullScreenGames: false)
        XCTAssertEqual(l.overlay, .screenSaver)
        XCTAssertEqual(l.panel.rawValue, NSWindow.Level.screenSaver.rawValue + 1)
    }

    func testGameModeSitsAboveTheDisplayShield() {
        let l = WindowLevels(coverFullScreenGames: true)
        XCTAssertGreaterThan(l.overlay.rawValue, Int(CGShieldingWindowLevel()))
        XCTAssertEqual(l.panel.rawValue, l.overlay.rawValue + 1)
        XCTAssertLessThanOrEqual(l.panel.rawValue, Int(Int32.max), "window levels are 32-bit")
    }

    func testPanelsAlwaysAboveOverlays() {
        for games in [false, true] {
            let l = WindowLevels(coverFullScreenGames: games)
            XCTAssertGreaterThan(l.panel.rawValue, l.overlay.rawValue)
        }
    }
}
