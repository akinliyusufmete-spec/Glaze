import XCTest
@testable import Glaze

final class ColorSlotsTests: XCTestCase {
    func testDefaultsHaveNineSlots() {
        XCTAssertEqual(ColorSlots().count, 9)
    }

    func testSelectionWrapsBothWays() {
        var s = ColorSlots()
        s.selectPrevious()
        XCTAssertEqual(s.selectedIndex, 8)
        s.selectNext()
        XCTAssertEqual(s.selectedIndex, 0)
    }

    func testSelectIgnoresOutOfRange() {
        var s = ColorSlots()
        s.select(99); s.select(-1)
        XCTAssertEqual(s.selectedIndex, 0)
    }

    func testReplaceSelected() {
        var s = ColorSlots()
        s.select(2)
        let new = RGBAColor(hex: "#123456")!
        s.replaceSelected(with: new)
        XCTAssertEqual(s.selected.hexString(), "#123456")
        XCTAssertEqual(s.count, 9)
    }

    func testSelectSlotMatching() {
        var s = ColorSlots()
        XCTAssertTrue(s.selectSlot(matching: RGBAColor(hex: "#34C759")!))
        XCTAssertEqual(s.selectedIndex, 3)
        XCTAssertFalse(s.selectSlot(matching: RGBAColor(hex: "#010203")!))
        XCTAssertEqual(s.selectedIndex, 3)
    }

    func testInitClampsIndex() {
        XCTAssertEqual(ColorSlots(selectedIndex: 40).selectedIndex, 8)
    }
}
