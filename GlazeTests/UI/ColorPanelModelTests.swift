import XCTest
@testable import Glaze

@MainActor
final class ColorPanelModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite = ""
    private var settings: ToolSettings!
    private var model: ColorPanelModel!

    override func setUp() {
        suite = "glaze.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        settings = ToolSettings(defaults: defaults)
        model = ColorPanelModel(settings: settings)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private func hex(_ s: String) -> RGBAColor { RGBAColor(hex: s)! }

    func testStartsOnTheStrokeColor() {
        XCTAssertEqual(model.color.hexString(), settings.strokeColor.hexString())
    }

    func testDraggingTheWheelUpdatesStrokeAndSelectedSlot() {
        model.hue = 2.0 / 3
        model.saturation = 1
        model.brightness = 1
        XCTAssertEqual(settings.strokeColor.hexString(), "#0000FF")
        XCTAssertEqual(settings.slots.colors[settings.slots.selectedIndex].hexString(), "#0000FF")
    }

    func testApplyHexColorGoesToTheTarget() {
        model.apply(hex("#123456"))
        XCTAssertEqual(settings.strokeColor.hexString(), "#123456")
        model.target = .fill
        model.apply(hex("#654321"))
        XCTAssertEqual(settings.fillColor.hexString(), "#654321")
        XCTAssertEqual(settings.strokeColor.hexString(), "#123456")
    }

    func testSwitchingTargetLoadsThatColor() {
        settings.pickFill(hex("#00FF00"))
        model.target = .fill
        XCTAssertEqual(model.color.hexString(), "#00FF00")
        model.target = .stroke
        XCTAssertEqual(model.color.hexString(), settings.strokeColor.hexString())
    }

    func testHueSurvivesDraggingBrightnessToBlack() {
        model.hue = 0.6
        model.saturation = 0.8
        model.brightness = 0
        model.brightness = 0.9
        XCTAssertEqual(model.hue, 0.6, accuracy: 1e-9)
        XCTAssertEqual(model.saturation, 0.8, accuracy: 1e-9)
    }

    func testApplyingBlackKeepsHueForLater() {
        model.hue = 0.3
        model.saturation = 0.5
        model.apply(hex("#000000"))
        XCTAssertEqual(model.hue, 0.3, accuracy: 1e-9)
        XCTAssertEqual(model.brightness, 0)
    }

    func testSelectSlotSwitchesBackToStroke() {
        model.target = .fill
        model.selectSlot(3)
        XCTAssertEqual(model.target, .stroke)
        XCTAssertEqual(model.color.hexString(), "#34C759")
        XCTAssertEqual(settings.slots.selectedIndex, 3)
    }

    func testOpacityEditKeepsAlphaInStroke() {
        model.alpha = 0.5
        XCTAssertEqual(Double(settings.strokeColor.a), 0.5, accuracy: 0.01)
    }

    func testCommitAddsToRecents() {
        model.apply(hex("#ABCDEF"))
        model.commit()
        XCTAssertEqual(model.recents.colors.first?.hexString(), "#ABCDEF")
    }

    func testSwapUpdatesTheEditedColor() {
        settings.pickFill(hex("#00FF00"))
        model.syncFromSettings()
        model.swapStrokeAndFill()
        XCTAssertEqual(model.color.hexString(), "#00FF00")
    }

    func testSyncFromSettingsFollowsHotkeySlotChange() {
        settings.selectSlot(4)
        model.syncFromSettings()
        XCTAssertEqual(model.color.hexString(), "#0A84FF")
    }
}
