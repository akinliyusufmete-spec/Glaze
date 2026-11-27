import XCTest
@testable import Glaze

final class DockTypesTests: XCTestCase {
    func testPlacementEdgeAndOrientation() {
        XCTAssertEqual(ToolbarPlacement.top.edge, .top)
        XCTAssertEqual(ToolbarPlacement.right.edge, .right)
        XCTAssertNil(ToolbarPlacement.floating.edge)
        XCTAssertTrue(ToolbarPlacement.left.isVertical)
        XCTAssertTrue(ToolbarPlacement.right.isVertical)
        XCTAssertFalse(ToolbarPlacement.top.isVertical)
        XCTAssertFalse(ToolbarPlacement.bottom.isVertical)
        XCTAssertFalse(ToolbarPlacement.floating.isVertical)
    }

    func testEveryEdgeIsAPlacement() {
        for edge in DockEdge.allCases { XCTAssertEqual(ToolbarPlacement(rawValue: edge.rawValue)?.edge, edge) }
    }

    func testAnimationStyleFlags() {
        XCTAssertFalse(AnimationStyle.none.slides); XCTAssertFalse(AnimationStyle.none.fades)
        XCTAssertTrue(AnimationStyle.fade.fades); XCTAssertFalse(AnimationStyle.fade.slides)
        XCTAssertTrue(AnimationStyle.slide.slides); XCTAssertFalse(AnimationStyle.slide.fades)
        XCTAssertTrue(AnimationStyle.slideFade.slides); XCTAssertTrue(AnimationStyle.slideFade.fades)
    }

    func testRawValuesAreStableForSavedPreferences() {
        XCTAssertEqual(ToolbarReveal.allCases.map(\.rawValue), ["always", "keybind", "edge"])
        XCTAssertEqual(AnimationStyle.allCases.map(\.rawValue), ["none", "fade", "slide", "slideFade"])
    }
}
