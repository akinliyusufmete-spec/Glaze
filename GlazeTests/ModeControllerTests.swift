import XCTest
@testable import Glaze

@MainActor
private final class SpySink: ModeSink {
    struct Call: Equatable {
        let mode: AppMode
        let previous: AppMode?
    }
    var calls: [Call] = []
    func apply(mode: AppMode, previous: AppMode?) {
        calls.append(Call(mode: mode, previous: previous))
    }
}

@MainActor
final class ModeControllerTests: XCTestCase {
    private var controller: ModeController!
    private var spy: SpySink!

    override func setUp() async throws {
        controller = ModeController()
        spy = SpySink()
        controller.attach(spy)
    }

    func testStartsInPointerAndAttachSyncsWithNilPrevious() {
        XCTAssertEqual(controller.mode, .pointer)
        XCTAssertEqual(spy.calls, [.init(mode: .pointer, previous: nil)])
    }

    func testToggleSwitchesBothWaysAndReportsPrevious() {
        controller.toggle()
        XCTAssertEqual(controller.mode, .draw(tool: .pen))
        controller.toggle()
        XCTAssertEqual(controller.mode, .pointer)
        XCTAssertEqual(spy.calls.dropFirst(), [
            .init(mode: .draw(tool: .pen), previous: .pointer),
            .init(mode: .pointer, previous: .draw(tool: .pen)),
        ])
    }

    func testTransitionToSameModeIsNoOp() {
        controller.transition(to: .pointer)
        controller.select(tool: .marker)
        controller.select(tool: .marker)
        XCTAssertEqual(spy.calls.count, 2)
    }

    func testResyncReappliesWithNilPrevious() {
        controller.toggle()
        controller.resync()
        XCTAssertEqual(spy.calls.last, .init(mode: .draw(tool: .pen), previous: nil))
    }

    func testToggleRestoresLastTool() {
        controller.select(tool: .highlighter)
        controller.exitToPointer()
        XCTAssertEqual(controller.mode, .pointer)
        controller.toggle()
        XCTAssertEqual(controller.mode, .draw(tool: .highlighter))
        XCTAssertEqual(controller.lastTool, .highlighter)
    }

    func testMomentaryDrawBeginsAndEndsFromPointer() {
        controller.beginMomentaryDraw()
        XCTAssertEqual(controller.mode, .momentaryDraw(returnTo: .pointer))
        XCTAssertTrue(controller.mode.capturesInput)
        controller.endMomentaryDraw()
        XCTAssertEqual(controller.mode, .pointer)
    }

    func testMomentaryDrawIgnoredWhileAlreadyDrawing() {
        controller.toggle()
        controller.beginMomentaryDraw()
        XCTAssertEqual(controller.mode, .draw(tool: .pen))
        controller.endMomentaryDraw()
        XCTAssertEqual(controller.mode, .draw(tool: .pen))
    }

    func testToggleDuringMomentaryLatchesIntoDraw() {
        controller.beginMomentaryDraw()
        controller.toggle()
        XCTAssertEqual(controller.mode, .draw(tool: .pen))
        controller.endMomentaryDraw()
        XCTAssertEqual(controller.mode, .draw(tool: .pen))
    }

    func testExitToPointerFromMomentary() {
        controller.beginMomentaryDraw()
        controller.exitToPointer()
        XCTAssertEqual(controller.mode, .pointer)
    }

    func testNestedMomentaryIsFlattened() {
        let nested = AppMode.momentaryDraw(returnTo: .momentaryDraw(returnTo: .draw(tool: .pen)))
        XCTAssertEqual(ModeController.normalize(nested), .momentaryDraw(returnTo: .draw(tool: .pen)))
        controller.transition(to: nested)
        XCTAssertEqual(controller.mode, .momentaryDraw(returnTo: .draw(tool: .pen)))
    }

    func testCapturesInputPerMode() {
        XCTAssertFalse(AppMode.pointer.capturesInput)
        XCTAssertTrue(AppMode.draw(tool: .pen).capturesInput)
        XCTAssertTrue(AppMode.momentaryDraw(returnTo: .pointer).capturesInput)
    }

    func testReleasedSinksAreDropped() {
        do {
            let temporary = SpySink()
            controller.attach(temporary)
        }
        controller.toggle() // the released sink must be skipped, not crash
        XCTAssertEqual(spy.calls.last?.mode, .draw(tool: .pen))
    }
}
