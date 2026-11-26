import XCTest
@testable import Glaze

final class CanvasTests: XCTestCase {
    func testAppendAndLookupBumpRevision() {
        var canvas = Canvas()
        let stroke = Fixtures.line()
        canvas.append(stroke)
        XCTAssertEqual(canvas.revision, 1)
        XCTAssertEqual(canvas.index(of: stroke.id), 0)
        XCTAssertEqual(canvas.element(withID: stroke.id)?.id, stroke.id)
        XCTAssertNil(canvas.element(withID: UUID()))
    }

    func testInsertClampsIndex() {
        var canvas = Canvas()
        let a = Fixtures.line(), b = Fixtures.line(), c = Fixtures.line()
        canvas.insert(a, at: 10)
        canvas.insert(b, at: -5)
        canvas.insert(c, at: 1)
        XCTAssertEqual(Fixtures.ids(canvas), [b.id, c.id, a.id])
    }

    func testRemoveReturnsOriginalIndicesAndClearsSelection() {
        var canvas = Canvas()
        let strokes = (0..<4).map { _ in Fixtures.line() }
        strokes.forEach { canvas.append($0) }
        canvas.selection = [strokes[1].id, strokes[2].id]
        let removed = canvas.remove(ids: [strokes[3].id, strokes[1].id])
        XCTAssertEqual(removed.map(\.index), [1, 3])
        XCTAssertEqual(Fixtures.ids(canvas), [strokes[0].id, strokes[2].id])
        XCTAssertEqual(canvas.selection, [strokes[2].id])
    }

    func testRemovingUnknownIDsIsANoOp() {
        var canvas = Canvas()
        canvas.append(Fixtures.line())
        let revision = canvas.revision
        XCTAssertTrue(canvas.remove(ids: [UUID()]).isEmpty)
        XCTAssertEqual(canvas.revision, revision)
    }

    func testRemoveAllAndReplaceAll() {
        var canvas = Canvas()
        let a = Fixtures.line(), b = Fixtures.line()
        canvas.append(a)
        canvas.append(b)
        let old = canvas.removeAll()
        XCTAssertTrue(canvas.isEmpty)
        canvas.replaceAll(with: old)
        XCTAssertEqual(Fixtures.ids(canvas), [a.id, b.id])
    }
}
