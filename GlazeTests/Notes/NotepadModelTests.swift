import XCTest
@testable import Glaze

@MainActor
final class NotepadModelTests: XCTestCase {
    private var dir: URL!
    private var url: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("glaze-pad-\(UUID().uuidString)")
        url = dir.appendingPathComponent("notebook.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeModel() -> NotepadModel {
        NotepadModel(storage: NotebookStorage(url: url), registry: ToolRegistry())
    }

    private func line(_ x: CGFloat = 0) -> StrokeElement {
        StrokeElement(points: [CGPoint(x: x, y: 0), CGPoint(x: x + 50, y: 30)],
                      color: RGBAColor(r: 1, g: 0, b: 0).cgColor, width: 4)
    }

    private func draw(_ model: NotepadModel, _ stroke: StrokeElement) {
        model.inkStore(for: model.currentPage.id)
            .perform(AddElement(element: stroke), on: NotepadModel.inkDisplayID)
    }

    func testDrawingIsRecordedOnThePage() {
        let model = makeModel()
        draw(model, line())
        XCTAssertEqual(model.currentPage.strokes.count, 1)
        XCTAssertTrue(model.canUndoInk)
    }

    func testUndoRedoAndClear() {
        let model = makeModel()
        draw(model, line()); draw(model, line(10))
        model.undoInk()
        XCTAssertEqual(model.currentPage.strokes.count, 1)
        XCTAssertTrue(model.canRedoInk)
        model.redoInk()
        XCTAssertEqual(model.currentPage.strokes.count, 2)
        model.clearInk()
        XCTAssertEqual(model.currentPage.strokes.count, 0)
        model.undoInk()
        XCTAssertEqual(model.currentPage.strokes.count, 2, "clear is one undoable step")
    }

    func testEachPageKeepsItsOwnInk() {
        let model = makeModel()
        draw(model, line())
        model.addPage()
        XCTAssertEqual(model.currentPage.strokes.count, 0)
        XCTAssertFalse(model.canUndoInk, "undo history is per page")
        model.goPrevious()
        XCTAssertEqual(model.currentPage.strokes.count, 1)
        XCTAssertTrue(model.canUndoInk)
    }

    func testTextAndInkSurviveARelaunch() {
        let model = makeModel()
        model.setText("buy milk", forPage: model.currentPage.id)
        draw(model, line())
        model.addPage()
        model.setText("page two", forPage: model.currentPage.id)
        model.flush()

        let reopened = makeModel()
        XCTAssertEqual(reopened.notebook.pageCount, 2)
        XCTAssertEqual(reopened.currentPage.text, "page two")
        reopened.goPrevious()
        XCTAssertEqual(reopened.currentPage.text, "buy milk")
        XCTAssertEqual(reopened.currentPage.strokes.count, 1)

        // The restored ink is really on the page's canvas, and it isn't an undo step.
        let store = reopened.inkStore(for: reopened.currentPage.id)
        XCTAssertEqual(store.canvas(for: NotepadModel.inkDisplayID).elements.count, 1)
        XCTAssertFalse(store.canUndo(on: NotepadModel.inkDisplayID))
    }

    func testDeletingAPageDropsItsInk() {
        let model = makeModel()
        draw(model, line())
        model.addPage()
        model.goPrevious()
        model.deleteCurrentPage()
        XCTAssertEqual(model.notebook.pageCount, 1)
        XCTAssertEqual(model.currentPage.strokes.count, 0)
    }

    func testClearingAnEmptyPageDoesNothing() {
        let model = makeModel()
        model.clearInk()
        XCTAssertFalse(model.canUndoInk)
    }

    func testModeToolAccessor() {
        XCTAssertNil(NotepadModel.Mode.type.tool)
        XCTAssertEqual(NotepadModel.Mode.draw(.pen).tool, .pen)
    }
}
