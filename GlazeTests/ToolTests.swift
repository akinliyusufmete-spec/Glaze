import XCTest
@testable import Glaze

@MainActor
final class ToolTests: XCTestCase {
    private var context: FakeToolContext!

    override func setUp() async throws {
        context = FakeToolContext()
    }

    private func p(_ x: CGFloat, _ y: CGFloat) -> InputPoint {
        InputPoint(location: CGPoint(x: x, y: y))
    }

    private func drag(_ tool: any Tool, _ points: [InputPoint]) {
        tool.begin(points[0], context: context)
        points.dropFirst().dropLast().forEach { tool.move($0, context: context) }
        tool.end(points[points.count - 1], context: context)
    }

    // MARK: Brush

    func testBrushStrokeCommitsOneUndoableElement() throws {
        let brush = BrushTool()
        brush.begin(p(0, 0), context: context)
        XCTAssertTrue(brush.isDrawing)
        let liveID = try XCTUnwrap(context.lastLive?.id)
        XCTAssertNotNil(context.liveCalls.last?.dirty)
        brush.move(p(10, 0), context: context)
        brush.move(p(10, 0), context: context) // duplicate: ignored
        brush.end(p(20, 0), context: context)

        XCTAssertFalse(brush.isDrawing)
        XCTAssertEqual(context.performed.count, 1)
        let stroke = try XCTUnwrap(context.canvas.elements.first as? StrokeElement)
        XCTAssertEqual(stroke.id, liveID, "the committed stroke is the one shown live")
        // The One-Euro filter moves the middle sample; the ends are exact.
        XCTAssertEqual(stroke.points.count, 3)
        XCTAssertEqual(stroke.points.first, CGPoint(x: 0, y: 0))
        XCTAssertEqual(stroke.points.last, CGPoint(x: 20, y: 0))
        XCTAssertEqual(stroke.points[1].y, 0, accuracy: 1e-9)
        XCTAssertNil(context.lastLive)

        context.undo()
        XCTAssertTrue(context.canvas.isEmpty)
        context.redo()
        XCTAssertEqual(context.canvas.elements.first?.id, liveID)
    }

    func testBrushStrokesGetDistinctIDs() {
        let brush = BrushTool()
        drag(brush, [p(0, 0), p(5, 5)])
        drag(brush, [p(0, 0), p(5, 5)])
        XCTAssertEqual(Set(Fixtures.ids(context.canvas)).count, 2)
    }

    func testBrushMoveWithoutBeginStartsStroke() {
        let brush = BrushTool()
        brush.move(p(3, 3), context: context)
        XCTAssertTrue(brush.isDrawing)
    }

    func testBrushCancelCommitsNothing() {
        let brush = BrushTool()
        brush.begin(p(0, 0), context: context)
        brush.move(p(10, 10), context: context)
        brush.cancel(context: context)
        XCTAssertFalse(brush.isDrawing)
        XCTAssertTrue(context.performed.isEmpty)
        XCTAssertNil(context.lastLive)
    }

    // MARK: Eraser

    func testEraserRemovesTouchedStrokesInOneUndoableCommand() {
        let top = Fixtures.line(y: 0), middle = Fixtures.line(y: 50), bottom = Fixtures.line(y: 100)
        [top, middle, bottom].forEach { context.perform(AddElement(element: $0)) }
        let eraser = EraserTool()

        // A vertical drag at x = 50 from y = -10 to y = 60 crosses top and middle.
        eraser.begin(p(50, -10), context: context)
        eraser.move(p(50, 60), context: context)
        XCTAssertEqual(context.pendingRemoval, [top.id, middle.id])
        XCTAssertEqual(context.canvas.elements.count, 3, "nothing is removed before mouse-up")
        eraser.end(p(50, 60), context: context)

        XCTAssertEqual(Fixtures.ids(context.canvas), [bottom.id])
        XCTAssertTrue(context.pendingRemoval.isEmpty)
        XCTAssertEqual(context.history.undoStack.count, 4)

        context.undo()
        XCTAssertEqual(Fixtures.ids(context.canvas), [top.id, middle.id, bottom.id])
    }

    func testEraserFastDragDoesNotSkipThinStrokes() {
        // One big jump between two events must still hit the stroke it crosses.
        let stroke = Fixtures.line(x0: 0, x1: 200, y: 100, width: 1)
        context.perform(AddElement(element: stroke))
        drag(EraserTool(), [p(100, 0), p(100, 400)])
        XCTAssertTrue(context.canvas.isEmpty)
    }

    func testEraserMissPerformsNoCommand() {
        context.perform(AddElement(element: Fixtures.line(y: 0)))
        let before = context.performed.count
        drag(EraserTool(), [p(0, 200), p(100, 200)])
        XCTAssertEqual(context.performed.count, before)
        XCTAssertEqual(context.canvas.elements.count, 1)
    }

    func testEraserCancelRemovesNothing() {
        context.perform(AddElement(element: Fixtures.line(y: 0)))
        let eraser = EraserTool()
        eraser.begin(p(50, 0), context: context)
        XCTAssertFalse(eraser.pending.isEmpty)
        eraser.cancel(context: context)
        XCTAssertTrue(eraser.pending.isEmpty)
        XCTAssertTrue(context.pendingRemoval.isEmpty)
        XCTAssertEqual(context.canvas.elements.count, 1)
    }

    // MARK: Registry

    func testRegistryBuildsImplementedToolsAndFallsBackToPen() {
        let registry = ToolRegistry()
        XCTAssertTrue(registry.isImplemented(.pen))
        XCTAssertTrue(registry.isImplemented(.eraser))
        XCTAssertFalse(registry.isImplemented(.rectangle))
        XCTAssertTrue(registry.makeTool(.eraser) is EraserTool)
        XCTAssertEqual(registry.makeTool(.rectangle).id, .pen)
    }

    func testRegistryRegistersEveryBrushButTheLaser() {
        let registry = ToolRegistry()
        for id in ToolRegistry.brushIDs {
            XCTAssertTrue(registry.isImplemented(id), "\(id)")
            XCTAssertEqual(registry.makeTool(id).id, id)
        }
        XCTAssertFalse(registry.isImplemented(.laser), "LaserTool arrives in Phase 5")
    }

    func testRegistryRegisterOverridesFallback() {
        let registry = ToolRegistry()
        registry.register(.rectangle) { EraserTool() }
        XCTAssertTrue(registry.isImplemented(.rectangle))
        XCTAssertTrue(registry.makeTool(.rectangle) is EraserTool)
    }

    // MARK: Brush presets

    func testHighlighterStraightensANearlyStraightDrag() throws {
        let tool = BrushTool(id: .highlighter, style: BrushPresets.highlighter)
        drag(tool, (0...20).map { i in p(CGFloat(i) * 5, i % 2 == 0 ? 0 : 1) })
        let stroke = try XCTUnwrap(context.canvas.elements.first as? StrokeElement)
        XCTAssertEqual(stroke.points.count, 2)
        XCTAssertEqual(stroke.points.first, CGPoint(x: 0, y: 0))
        XCTAssertEqual(stroke.points.last, CGPoint(x: 100, y: 0))
    }

    func testPenDoesNotStraighten() throws {
        drag(BrushTool(), (0...20).map { i in p(CGFloat(i) * 5, i % 2 == 0 ? 0 : 1) })
        let stroke = try XCTUnwrap(context.canvas.elements.first as? StrokeElement)
        XCTAssertGreaterThan(stroke.points.count, 2)
    }
}
