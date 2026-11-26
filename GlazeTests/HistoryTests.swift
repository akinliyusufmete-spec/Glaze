import XCTest
@testable import Glaze

final class HistoryTests: XCTestCase {
    private var canvas = Canvas()
    private var history = History()

    override func setUp() {
        canvas = Canvas()
        history = History()
    }

    func testPerformAppliesAndUndoRedoRoundTrip() {
        let stroke = Fixtures.line()
        history.perform(AddElement(element: stroke), on: &canvas)
        XCTAssertEqual(Fixtures.ids(canvas), [stroke.id])
        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)

        XCTAssertTrue(history.undo(on: &canvas))
        XCTAssertTrue(canvas.isEmpty)
        XCTAssertTrue(history.canRedo)

        XCTAssertTrue(history.redo(on: &canvas))
        XCTAssertEqual(Fixtures.ids(canvas), [stroke.id])
        XCTAssertFalse(history.canRedo)
    }

    func testUndoAndRedoOnEmptyStacksReturnFalse() {
        XCTAssertFalse(history.undo(on: &canvas))
        XCTAssertFalse(history.redo(on: &canvas))
        XCTAssertEqual(canvas.revision, 0)
    }

    func testNewPerformClearsRedo() {
        history.perform(AddElement(element: Fixtures.line()), on: &canvas)
        history.undo(on: &canvas)
        XCTAssertTrue(history.canRedo)
        history.perform(AddElement(element: Fixtures.line()), on: &canvas)
        XCTAssertFalse(history.canRedo)
    }

    func testUndoesInReverseOrder() {
        let strokes = (0..<3).map { _ in Fixtures.line() }
        strokes.forEach { history.perform(AddElement(element: $0), on: &canvas) }
        history.undo(on: &canvas)
        XCTAssertEqual(Fixtures.ids(canvas), strokes.prefix(2).map(\.id))
        history.undo(on: &canvas)
        XCTAssertEqual(Fixtures.ids(canvas), [strokes[0].id])
    }

    func testLimitDropsOldestCommands() {
        history = History(limit: 3)
        let strokes = (0..<5).map { _ in Fixtures.line() }
        strokes.forEach { history.perform(AddElement(element: $0), on: &canvas) }
        XCTAssertEqual(history.undoStack.count, 3)
        while history.undo(on: &canvas) {}
        // The two oldest strokes can no longer be undone.
        XCTAssertEqual(Fixtures.ids(canvas), strokes.prefix(2).map(\.id))
    }

    func testLimitIsAtLeastOne() {
        XCTAssertEqual(History(limit: 0).limit, 1)
        XCTAssertEqual(History().limit, History.defaultLimit)
    }
}
