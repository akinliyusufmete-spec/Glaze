import XCTest
import CoreGraphics
@testable import Glaze

final class PanelPlacementTests: XCTestCase {
    private let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let size = CGSize(width: 200, height: 300)

    func testPlacesRightWithTopsAligned() {
        let anchor = CGRect(x: 100, y: 700, width: 300, height: 40)
        let f = PanelPlacement.frame(panelSize: size, anchor: anchor, visible: visible, preferred: .right, gap: 8)
        XCTAssertEqual(f.minX, 408)
        XCTAssertEqual(f.maxY, 740)
    }

    func testFlipsToLeftWhenNoRoomOnRight() {
        let anchor = CGRect(x: 700, y: 700, width: 280, height: 40)   // maxX 980
        let f = PanelPlacement.frame(panelSize: size, anchor: anchor, visible: visible, preferred: .right, gap: 8)
        XCTAssertEqual(f.maxX, 692)
    }

    func testBelowFlipsAboveNearBottom() {
        let anchor = CGRect(x: 300, y: 100, width: 300, height: 40)   // no room below (needs 308)
        let f = PanelPlacement.frame(panelSize: size, anchor: anchor, visible: visible, preferred: .below, gap: 8)
        XCTAssertEqual(f.minY, 148)
        XCTAssertEqual(f.minX, 300)
    }

    func testBelowStaysBelowWhenItFits() {
        let anchor = CGRect(x: 300, y: 700, width: 300, height: 40)
        let f = PanelPlacement.frame(panelSize: size, anchor: anchor, visible: visible, preferred: .below, gap: 8)
        XCTAssertEqual(f.maxY, 692)
    }

    func testClampsCrossAxisIntoVisible() {
        let anchor = CGRect(x: 900, y: 700, width: 90, height: 40)    // below, but 200 wide panel overflows right
        let f = PanelPlacement.frame(panelSize: size, anchor: anchor, visible: visible, preferred: .below, gap: 8)
        XCTAssertEqual(f.maxX, 1000)
        XCTAssertTrue(visible.contains(f))
    }

    func testOversizedPanelKeepsTopLeftVisible() {
        let tiny = CGRect(x: 0, y: 0, width: 150, height: 150)
        let anchor = CGRect(x: 10, y: 100, width: 100, height: 30)
        let f = PanelPlacement.frame(panelSize: size, anchor: anchor, visible: tiny, preferred: .right)
        XCTAssertEqual(f.minX, 0)
        XCTAssertEqual(f.maxY, 150)
    }

    func testResultAlwaysInsideVisibleWhenPanelFits() {
        for x in stride(from: 0.0, through: 900.0, by: 150) {
            for y in stride(from: 0.0, through: 760.0, by: 190) {
                for side in PanelPlacement.Side.allCases {
                    let anchor = CGRect(x: x, y: y, width: 100, height: 40)
                    let f = PanelPlacement.frame(panelSize: size, anchor: anchor, visible: visible, preferred: side)
                    XCTAssertTrue(visible.contains(f), "\(anchor) \(side) -> \(f)")
                }
            }
        }
    }
}
