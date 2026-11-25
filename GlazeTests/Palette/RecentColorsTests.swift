import XCTest
@testable import Glaze

final class RecentColorsTests: XCTestCase {
    private func c(_ hex: String) -> RGBAColor { RGBAColor(hex: hex)! }

    func testNewestFirst() {
        var r = RecentColors()
        r.record(c("#111111")); r.record(c("#222222"))
        XCTAssertEqual(r.colors.map { $0.hexString() }, ["#222222", "#111111"])
    }

    func testDuplicateMovesToFront() {
        var r = RecentColors()
        r.record(c("#111111")); r.record(c("#222222")); r.record(c("#111111"))
        XCTAssertEqual(r.colors.map { $0.hexString() }, ["#111111", "#222222"])
    }

    func testAlphaDistinguishesColors() {
        var r = RecentColors()
        r.record(c("#11111180")); r.record(c("#111111FF"))
        XCTAssertEqual(r.colors.count, 2)
    }

    func testCapacityTrimsOldest() {
        var r = RecentColors(capacity: 3)
        for hex in ["#000001", "#000002", "#000003", "#000004"] { r.record(c(hex)) }
        XCTAssertEqual(r.colors.map { $0.hexString() }, ["#000004", "#000003", "#000002"])
    }

    func testInitKeepsGivenOrder() {
        let r = RecentColors(colors: [c("#000001"), c("#000002")])
        XCTAssertEqual(r.colors.first?.hexString(), "#000001")
    }
}
