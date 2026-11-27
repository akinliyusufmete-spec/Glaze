import XCTest
import CoreGraphics
@testable import Glaze

final class DockGeometryTests: XCTestCase {
    private let visible = CGRect(x: 0, y: 0, width: 1440, height: 860)
    private let horizontal = CGSize(width: 600, height: 44)
    private let vertical = CGSize(width: 44, height: 520)
    private let m = DockGeometry.margin

    func testTopIsCentredBelowTheTopEdge() {
        let f = DockGeometry.shownFrame(size: horizontal, edge: .top, in: visible)
        XCTAssertEqual(f.midX, visible.midX)
        XCTAssertEqual(f.maxY, visible.maxY - m)
    }

    func testBottomIsCentredAboveTheBottomEdge() {
        let f = DockGeometry.shownFrame(size: horizontal, edge: .bottom, in: visible)
        XCTAssertEqual(f.midX, visible.midX)
        XCTAssertEqual(f.minY, visible.minY + m)
    }

    func testLeftAndRightAreCentredVertically() {
        let l = DockGeometry.shownFrame(size: vertical, edge: .left, in: visible)
        XCTAssertEqual(l.minX, visible.minX + m)
        XCTAssertEqual(l.midY, visible.midY)
        let r = DockGeometry.shownFrame(size: vertical, edge: .right, in: visible)
        XCTAssertEqual(r.maxX, visible.maxX - m)
        XCTAssertEqual(r.midY, visible.midY)
    }

    func testShownFrameStaysInsideWhenTooBig() {
        let f = DockGeometry.shownFrame(size: CGSize(width: 2000, height: 44), edge: .top, in: visible)
        XCTAssertEqual(f.minX, visible.minX)
    }

    func testHiddenFrameIsEntirelyPastItsEdge() {
        for edge in DockEdge.allCases {
            let size = edge.isVertical ? vertical : horizontal
            let shown = DockGeometry.shownFrame(size: size, edge: edge, in: visible)
            let hidden = DockGeometry.hiddenFrame(from: shown, edge: edge)
            XCTAssertFalse(hidden.intersects(visible), "\(edge)")
            XCTAssertEqual(hidden.size, shown.size)
        }
    }

    func testHiddenFrameMovesAlongTheRightAxis() {
        let shown = DockGeometry.shownFrame(size: horizontal, edge: .top, in: visible)
        let hidden = DockGeometry.hiddenFrame(from: shown, edge: .top)
        XCTAssertEqual(hidden.minX, shown.minX)
        XCTAssertGreaterThan(hidden.minY, shown.minY)
    }

    func testHandleIsFlushWithItsEdgeAndCentred() {
        let long = DockGeometry.handleLength, thin = DockGeometry.handleThickness
        let t = DockGeometry.handleFrame(edge: .top, in: visible)
        XCTAssertEqual(t.maxY, visible.maxY); XCTAssertEqual(t.midX, visible.midX)
        XCTAssertEqual(t.size, CGSize(width: long, height: thin))
        let b = DockGeometry.handleFrame(edge: .bottom, in: visible)
        XCTAssertEqual(b.minY, visible.minY)
        let l = DockGeometry.handleFrame(edge: .left, in: visible)
        XCTAssertEqual(l.minX, visible.minX); XCTAssertEqual(l.midY, visible.midY)
        XCTAssertEqual(l.size, CGSize(width: thin, height: long))
        let r = DockGeometry.handleFrame(edge: .right, in: visible)
        XCTAssertEqual(r.maxX, visible.maxX)
    }

    func testColorPanelOpensAwayFromTheDockEdge() {
        XCTAssertEqual(DockGeometry.attachedSide(for: .top), .below)
        XCTAssertEqual(DockGeometry.attachedSide(for: .bottom), .above)
        XCTAssertEqual(DockGeometry.attachedSide(for: .left), .right)
        XCTAssertEqual(DockGeometry.attachedSide(for: .right), .left)
        XCTAssertEqual(DockGeometry.attachedSide(for: .floating), .below)
    }
}
