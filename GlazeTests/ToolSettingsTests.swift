import XCTest
@testable import Glaze

@MainActor
final class ToolSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUp() {
        suite = "glaze.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private func hex(_ s: String) -> RGBAColor { RGBAColor(hex: s)! }

    func testStrokeColorIsTheSelectedSlot() {
        let s = ToolSettings(defaults: defaults)
        XCTAssertEqual(s.strokeColor, s.slots.selected)
        s.selectSlot(3)
        XCTAssertEqual(s.strokeColor.hexString(), "#34C759")
    }

    func testPickStrokeReplacesSelectedSlotOnly() {
        let s = ToolSettings(defaults: defaults)
        let before = s.slots.colors
        s.selectSlot(2)
        s.pickStroke(hex("#123456"))
        XCTAssertEqual(s.strokeColor.hexString(), "#123456")
        XCTAssertEqual(s.slots.colors[2].hexString(), "#123456")
        XCTAssertEqual(s.slots.colors[0], before[0])
        XCTAssertEqual(s.slots.count, 9)
    }

    func testSelectSlotIgnoresOutOfRange() {
        let s = ToolSettings(defaults: defaults)
        s.selectSlot(99)
        XCTAssertEqual(s.slots.selectedIndex, 0)
    }

    func testPickFillLeavesStrokeAlone() {
        let s = ToolSettings(defaults: defaults)
        let stroke = s.strokeColor
        s.pickFill(hex("#ABCDEF"))
        XCTAssertEqual(s.fillColor.hexString(), "#ABCDEF")
        XCTAssertEqual(s.strokeColor, stroke)
    }

    func testSwapExchangesStrokeAndFill() {
        let s = ToolSettings(defaults: defaults)
        s.pickStroke(hex("#111111"))
        s.pickFill(hex("#EEEEEE"))
        s.swapStrokeAndFill()
        XCTAssertEqual(s.strokeColor.hexString(), "#EEEEEE")
        XCTAssertEqual(s.fillColor.hexString(), "#111111")
    }

    func testRecentsRecordAndPersist() {
        let s = ToolSettings(defaults: defaults)
        s.commitRecent(hex("#010203"))
        s.commitRecent(hex("#040506"))
        let reloaded = ToolSettings(defaults: defaults)
        XCTAssertEqual(reloaded.recents.colors.map { $0.hexString() }, ["#040506", "#010203"])
    }

    func testWidthStepsAlongLadderFromPreset() {
        let s = ToolSettings(defaults: defaults)
        XCTAssertNil(s.width(for: .pen))
        XCTAssertEqual(s.stepWidth(for: .pen, presetWidth: 4, up: true), 6)
        XCTAssertEqual(s.width(for: .pen), 6)
        XCTAssertEqual(s.stepWidth(for: .pen, presetWidth: 4, up: false), 4)
        XCTAssertNil(s.width(for: .marker), "sizes are per brush")
    }

    func testWidthStopsAtLadderEnds() {
        let s = ToolSettings(defaults: defaults)
        s.setWidth(64, for: .pen)
        XCTAssertEqual(s.stepWidth(for: .pen, presetWidth: 4, up: true), 64)
        s.setWidth(1, for: .pen)
        XCTAssertEqual(s.stepWidth(for: .pen, presetWidth: 4, up: false), 1)
    }

    func testEverythingPersistsAcrossInstances() {
        let a = ToolSettings(defaults: defaults)
        a.selectSlot(4)
        a.pickStroke(hex("#445566"))
        a.pickFill(hex("#778899"))
        a.setWidth(12, for: .highlighter)

        let b = ToolSettings(defaults: defaults)
        XCTAssertEqual(b.slots.selectedIndex, 4)
        XCTAssertEqual(b.strokeColor.hexString(), "#445566")
        XCTAssertEqual(b.fillColor.hexString(), "#778899")
        XCTAssertEqual(b.width(for: .highlighter), 12)
    }

    // MARK: Brush tool + registry integration

    func testBrushToolReadsColorAndWidthAtStrokeStart() throws {
        let s = ToolSettings(defaults: defaults)
        s.pickStroke(hex("#00FF00"))
        s.setWidth(24, for: .pen)
        let tool = BrushTool(id: .pen, style: BrushPresets.pen, settings: s)
        let context = FakeToolContext()

        tool.begin(InputPoint(location: .zero), context: context)
        s.pickStroke(hex("#FF0000"))                       // changed mid-stroke: must not apply
        tool.move(InputPoint(location: CGPoint(x: 20, y: 0)), context: context)
        tool.end(InputPoint(location: CGPoint(x: 40, y: 0)), context: context)

        let stroke = try XCTUnwrap(context.canvas.elements.first as? StrokeElement)
        XCTAssertEqual(RGBAColor(stroke.color).hexString(), "#00FF00")
        XCTAssertEqual(stroke.style.baseWidth, 24)

        tool.begin(InputPoint(location: .zero), context: context)
        tool.end(InputPoint(location: CGPoint(x: 40, y: 0)), context: context)
        let second = try XCTUnwrap(context.canvas.elements.last as? StrokeElement)
        XCTAssertEqual(RGBAColor(second.color).hexString(), "#FF0000")
    }

    func testRegistryWithSettingsBuildsSettingsDrivenBrushes() {
        let s = ToolSettings(defaults: defaults)
        let registry = ToolRegistry(settings: s)
        s.pickStroke(hex("#0000FF"))
        let tool = registry.makeTool(.highlighter) as? BrushTool
        XCTAssertEqual(tool?.color.usingColorSpace(.sRGB)?.blueComponent ?? 0, 1, accuracy: 0.001)
    }
}
