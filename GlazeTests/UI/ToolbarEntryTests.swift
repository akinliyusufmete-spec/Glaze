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

    func testTooltipIncludesShortcut() {
        XCTAssertEqual(ToolbarEntry(id: "a", title: "Pen", symbol: "pencil", shortcutHint: "P").tooltip, "Pen (P)")
        XCTAssertEqual(ToolbarEntry(id: "a", title: "Pen", symbol: "pencil").tooltip, "Pen")
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
