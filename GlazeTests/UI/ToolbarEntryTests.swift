import XCTest
import AppKit
@testable import Glaze

final class ToolbarEntryTests: XCTestCase {
    func testResolvesPrimarySymbol() {
        let e = ToolbarEntry(id: "pen", title: "Pen", symbol: "pencil")
        XCTAssertEqual(e.resolvedSymbol, "pencil")
    }

    func testFallsBackWhenPrimaryMissing() {
        let e = ToolbarEntry(id: "x", title: "X", symbol: "definitely.not.a.symbol", fallbackSymbol: "pencil")
        XCTAssertEqual(e.resolvedSymbol, "pencil")
    }

    func testNilWhenNothingResolves() {
        let e = ToolbarEntry(id: "x", title: "X", symbol: "no.such.symbol", fallbackSymbol: "also.no.such")
        XCTAssertNil(e.resolvedSymbol)
    }

    func testHintCarriesTitleDetailAndShortcutAction() {
        let withKey = ToolbarEntry(id: "a", title: "Pen", detail: "Draws.", symbol: "pencil", shortcutAction: "toolPen").hint
        XCTAssertEqual(withKey, Hint(title: "Pen", detail: "Draws.", actionID: "toolPen"))
        let without = ToolbarEntry(id: "a", title: "Pen", symbol: "pencil").hint
        XCTAssertNil(without.detail)
        XCTAssertNil(without.actionID)
    }
}

final class ToolbarDefaultsTests: XCTestCase {
    func testIdsAreUnique() {
        let ids = ToolbarEntry.defaults.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryToolEntryIsARealToolID() {
        for e in ToolbarEntry.defaults where e.kind == .tool {
            XCTAssertNotNil(ToolID(rawValue: e.id), e.id)
        }
    }

    func testEveryNonSeparatorEntryResolvesASymbol() {
        for e in ToolbarEntry.defaults where e.kind != .separator {
            XCTAssertNotNil(e.resolvedSymbol, "\(e.id): \(e.symbol) / \(e.fallbackSymbol ?? "-")")
        }
    }

    func testToolbarOffersEveryImplementedBrush() {
        let ids = Set(ToolbarEntry.defaults.map(\.id))
        for id in ToolRegistry.brushIDs { XCTAssertTrue(ids.contains(id.rawValue), "\(id)") }
        XCTAssertTrue(ids.contains(ToolID.eraser.rawValue))
    }
}

final class ToolbarHintCoverageTests: XCTestCase {
    func testEveryButtonHasAnExplanationAndARealShortcutAction() {
        for e in ToolbarEntry.defaults where e.kind != .separator {
            XCTAssertFalse(e.detail.isEmpty, "\(e.id) needs a hover explanation")
            XCTAssertNotNil(e.shortcutAction.flatMap(ShortcutCatalog.action), "\(e.id) points at an unknown shortcut")
        }
    }

    func testToolbarOffersTheLaser() {
        XCTAssertTrue(ToolbarEntry.defaults.contains { $0.id == ToolID.laser.rawValue && $0.kind == .tool })
    }

    func testBrushSizeIsASliderNotButtons() {
        let ids = Set(ToolbarEntry.defaults.map(\.id))
        XCTAssertFalse(ids.contains(ToolbarActionID.sizeUp))
        XCTAssertFalse(ids.contains(ToolbarActionID.sizeDown))
    }
}

final class ToolbarNotepadEntryTests: XCTestCase {
    func testToolbarHasANotepadButton() {
        XCTAssertTrue(ToolbarEntry.defaults.contains { $0.id == ToolbarActionID.notepad && $0.kind == .action })
    }
}
