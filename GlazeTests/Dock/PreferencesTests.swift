import XCTest
@testable import Glaze

@MainActor
final class PreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUp() {
        suite = "glaze.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testDefaults() {
        let p = Preferences(defaults: defaults)
        XCTAssertEqual(p.toolbarPlacement, .top)
        XCTAssertEqual(p.toolbarReveal, .always)
        XCTAssertEqual(p.autoHideDelay, 2.0)
        XCTAssertEqual(p.animationStyle, .slideFade)
        XCTAssertEqual(p.animationDuration, 0.22, accuracy: 1e-9)
        XCTAssertTrue(p.hintsEnabled)
        XCTAssertEqual(p.hintDelay, 0.45, accuracy: 1e-9)
        XCTAssertTrue(p.showToolbar)
    }

    func testEverythingPersists() {
        let a = Preferences(defaults: defaults)
        a.toolbarPlacement = .right
        a.toolbarReveal = .edge
        a.autoHideDelay = 3.5
        a.animationStyle = .fade
        a.animationDuration = 0.4
        a.hintsEnabled = false
        a.hintDelay = 0.9

        let b = Preferences(defaults: defaults)
        XCTAssertEqual(b.toolbarPlacement, .right)
        XCTAssertEqual(b.toolbarReveal, .edge)
        XCTAssertEqual(b.autoHideDelay, 3.5)
        XCTAssertEqual(b.animationStyle, .fade)
        XCTAssertEqual(b.animationDuration, 0.4, accuracy: 1e-9)
        XCTAssertFalse(b.hintsEnabled)
        XCTAssertEqual(b.hintDelay, 0.9, accuracy: 1e-9)
    }

    func testOutOfRangeAndUnknownSavedValuesAreRepaired() {
        defaults.set("sideways", forKey: "toolbarPlacement")
        defaults.set("nonsense", forKey: "animationStyle")
        defaults.set(99.0, forKey: "autoHideDelay")
        defaults.set(-3.0, forKey: "animationDuration")
        defaults.set(50.0, forKey: "hintDelay")
        let p = Preferences(defaults: defaults)
        XCTAssertEqual(p.toolbarPlacement, .top)
        XCTAssertEqual(p.animationStyle, .slideFade)
        XCTAssertEqual(p.autoHideDelay, Preferences.autoHideRange.upperBound)
        XCTAssertEqual(p.animationDuration, Preferences.animationDurationRange.lowerBound)
        XCTAssertEqual(p.hintDelay, Preferences.hintDelayRange.upperBound)
    }

    func testOnChangeFiresForEachSetting() {
        let p = Preferences(defaults: defaults)
        var count = 0
        p.onChange = { count += 1 }
        p.toolbarPlacement = .left
        p.toolbarReveal = .keybind
        p.animationStyle = .none
        p.hintsEnabled = false
        XCTAssertEqual(count, 4)
    }
}
