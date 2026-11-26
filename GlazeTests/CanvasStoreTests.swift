import XCTest
@testable import Glaze

@MainActor
final class CanvasStoreTests: XCTestCase {
    private var store: CanvasStore!
    private var changes: [CanvasStore.DisplayID] = []
    private let main: CanvasStore.DisplayID = 1
    private let side: CanvasStore.DisplayID = 2

    override func setUp() async throws {
        store = CanvasStore()
        changes = []
        store.onChange = { [unowned self] id in changes.append(id) }
    }

    func testUnknownDisplayIsEmpty() {
        XCTAssertTrue(store.canvas(for: 42).isEmpty)
        XCTAssertFalse(store.canUndo(on: 42))
        XCTAssertFalse(store.undo(on: 42))
        XCTAssertTrue(changes.isEmpty)
    }

    func testDisplaysAreIndependent() {
        let a = Fixtures.line(), b = Fixtures.line()
        store.perform(AddElement(element: a), on: main)
        store.perform(AddElement(element: b), on: side)
        XCTAssertEqual(store.displayIDs, [main, side])

        store.undo(on: main)
        XCTAssertTrue(store.canvas(for: main).isEmpty)
        XCTAssertEqual(Fixtures.ids(store.canvas(for: side)), [b.id])
        XCTAssertEqual(store.redoCount(on: main), 1)
        XCTAssertEqual(store.redoCount(on: side), 0)
        XCTAssertEqual(store.undoCount(on: side), 1)
    }

    func testClearOnOneDisplayIsUndoableThere() {
        let a = Fixtures.line(), b = Fixtures.line()
        store.perform(AddElement(element: a), on: main)
        store.perform(AddElement(element: b), on: side)
        store.perform(ClearCanvas(canvas: store.canvas(for: main)), on: main)
        XCTAssertTrue(store.canvas(for: main).isEmpty)
        XCTAssertEqual(Fixtures.ids(store.canvas(for: side)), [b.id])

        XCTAssertTrue(store.undo(on: main))
        XCTAssertEqual(Fixtures.ids(store.canvas(for: main)), [a.id])
        XCTAssertTrue(store.redo(on: main))
        XCTAssertTrue(store.canvas(for: main).isEmpty)
    }

    func testOnChangeFiresForEveryMutationOnItsDisplay() {
        store.perform(AddElement(element: Fixtures.line()), on: side)
        store.undo(on: side)
        store.redo(on: side)
        store.redo(on: side) // nothing to redo: no change
        XCTAssertEqual(changes, [side, side, side])
    }
}
