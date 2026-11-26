import XCTest
@testable import Glaze

/// Every command must leave the canvas exactly as it found it after
/// apply → revert, and be replayable after revert (redo).
final class CommandTests: XCTestCase {
    private func canvas(with count: Int) -> (Canvas, [StrokeElement]) {
        var canvas = Canvas()
        let strokes = (0..<count).map { _ in Fixtures.line() }
        strokes.forEach { canvas.append($0) }
        return (canvas, strokes)
    }

    func testAddElementApplyAndRevert() {
        var (canvas, strokes) = canvas(with: 2)
        let added = Fixtures.line()
        let command = AddElement(element: added)
        command.apply(to: &canvas)
        XCTAssertEqual(Fixtures.ids(canvas), strokes.map(\.id) + [added.id])
        command.revert(on: &canvas)
        XCTAssertEqual(Fixtures.ids(canvas), strokes.map(\.id))
    }

    func testRemoveElementsRestoresOriginalOrder() {
        var (canvas, strokes) = canvas(with: 5)
        let original = Fixtures.ids(canvas)
        let command = RemoveElements(ids: [strokes[0].id, strokes[2].id, strokes[4].id], in: canvas)
        XCTAssertEqual(command.removed.map(\.index), [0, 2, 4])

        command.apply(to: &canvas)
        XCTAssertEqual(Fixtures.ids(canvas), [strokes[1].id, strokes[3].id])
        command.revert(on: &canvas)
        XCTAssertEqual(Fixtures.ids(canvas), original)
        command.apply(to: &canvas)
        XCTAssertEqual(Fixtures.ids(canvas), [strokes[1].id, strokes[3].id])
    }

    func testRemoveElementsIgnoresUnknownIDs() {
        let (canvas, strokes) = canvas(with: 2)
        XCTAssertTrue(RemoveElements(ids: [UUID()], in: canvas).isEmpty)
        XCTAssertEqual(RemoveElements(ids: [UUID(), strokes[1].id], in: canvas).removed.count, 1)
    }

    func testClearCanvasIsUndoable() {
        var (canvas, _) = canvas(with: 4)
        let original = Fixtures.ids(canvas)
        var history = History()
        history.perform(ClearCanvas(canvas: canvas), on: &canvas)
        XCTAssertTrue(canvas.isEmpty)
        history.undo(on: &canvas)
        XCTAssertEqual(Fixtures.ids(canvas), original)
        history.redo(on: &canvas)
        XCTAssertTrue(canvas.isEmpty)
    }

    func testMixedSequenceRevertsThroughHistory() {
        var canvas = Canvas()
        var history = History()
        let a = Fixtures.line(), b = Fixtures.line(), c = Fixtures.line()
        history.perform(AddElement(element: a), on: &canvas)
        history.perform(AddElement(element: b), on: &canvas)
        history.perform(RemoveElements(ids: [a.id], in: canvas), on: &canvas)
        history.perform(AddElement(element: c), on: &canvas)
        history.perform(ClearCanvas(canvas: canvas), on: &canvas)
        XCTAssertTrue(canvas.isEmpty)

        var states: [[UUID]] = []
        while history.undo(on: &canvas) { states.append(Fixtures.ids(canvas)) }
        XCTAssertEqual(states, [[b.id, c.id], [b.id], [a.id, b.id], [a.id], []])
        while history.redo(on: &canvas) {}
        XCTAssertTrue(canvas.isEmpty)
    }
}
