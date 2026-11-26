import XCTest
@testable import Glaze

final class NotebookTests: XCTestCase {
    func testStartsWithOneEmptyPage() {
        let n = Notebook()
        XCTAssertEqual(n.pageCount, 1)
        XCTAssertEqual(n.selectedIndex, 0)
        XCTAssertTrue(n.currentPage.isEmpty)
    }

    func testAddPageInsertsAfterCurrentAndSelectsIt() {
        var n = Notebook()
        let first = n.currentPage.id
        n.addPage()
        n.addPage()
        n.goPrevious()                      // on page 2 of 3
        n.addPage()                         // goes between 2 and 3
        XCTAssertEqual(n.pageCount, 4)
        XCTAssertEqual(n.selectedIndex, 2)
        XCTAssertEqual(n.pages[0].id, first)
    }

    func testNavigationStopsAtTheEnds() {
        var n = Notebook()
        n.addPage()
        XCTAssertFalse(n.canGoNext)
        n.goNext()
        XCTAssertEqual(n.selectedIndex, 1)
        n.goPrevious(); n.goPrevious()
        XCTAssertEqual(n.selectedIndex, 0)
        XCTAssertFalse(n.canGoPrevious)
    }

    func testDeleteMiddlePageKeepsAValidSelection() {
        var n = Notebook()
        n.addPage(); n.addPage()            // 3 pages, on the last
        let doomed = n.currentPage.id
        XCTAssertEqual(n.deleteCurrentPage(), doomed)
        XCTAssertEqual(n.pageCount, 2)
        XCTAssertEqual(n.selectedIndex, 1)
    }

    func testDeletingTheOnlyPageEmptiesItInstead() {
        var n = Notebook()
        let old = n.currentPage.id
        n.setText("hello", forPage: old)
        n.deleteCurrentPage()
        XCTAssertEqual(n.pageCount, 1)
        XCTAssertTrue(n.currentPage.isEmpty)
        XCTAssertNotEqual(n.currentPage.id, old)
    }

    func testSetTextAndStrokesTargetThePageByID() {
        var n = Notebook()
        let first = n.currentPage.id
        n.addPage()
        n.setText("on page one", forPage: first)
        XCTAssertEqual(n.pages[0].text, "on page one")
        XCTAssertEqual(n.pages[1].text, "")
        n.setText("ignored", forPage: UUID())
        XCTAssertEqual(n.pages.map(\.text), ["on page one", ""])
    }

    func testSetTextOnlyTouchesModifiedWhenTextChanges() {
        var n = Notebook()
        let id = n.currentPage.id
        let t0 = Date(timeIntervalSince1970: 100)
        n.setText("a", forPage: id, at: t0)
        n.setText("a", forPage: id, at: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(n.currentPage.modified, t0)
    }

    func testCodableRoundTrip() throws {
        var n = Notebook()
        n.setText("note", forPage: n.currentPage.id)
        n.addPage()
        let decoded = try JSONDecoder().decode(Notebook.self, from: JSONEncoder().encode(n))
        XCTAssertEqual(decoded, n)
    }

    func testDecodingRepairsEmptyOrOutOfRangeFiles() throws {
        let empty = try JSONDecoder().decode(Notebook.self, from: Data(#"{"version":1,"pages":[],"selectedIndex":5}"#.utf8))
        XCTAssertEqual(empty.pageCount, 1)
        XCTAssertEqual(empty.selectedIndex, 0)

        let page = #"{"id":"00000000-0000-0000-0000-000000000001","text":"x","strokes":[],"modified":0}"#
        let clamped = try JSONDecoder().decode(
            Notebook.self, from: Data(#"{"version":1,"pages":[\#(page)],"selectedIndex":9}"#.utf8))
        XCTAssertEqual(clamped.selectedIndex, 0)
        XCTAssertEqual(clamped.currentPage.text, "x")
    }
}
