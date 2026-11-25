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
