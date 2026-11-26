import XCTest
import CoreGraphics
@testable import Glaze

final class LaserTrailElementTests: XCTestCase {
    private let red = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)

    private func trail(_ points: [(CGPoint, TimeInterval)], life: TimeInterval = 1) -> LaserTrailElement {
        LaserTrailElement(points: points.map { .init(location: $0.0, age: $0.1) }, life: life, color: red, width: 5)
    }

    func testOpacityFadesWithAge() {
        XCTAssertEqual(LaserTrailElement.opacity(forAge: 0, life: 1), 1)
        XCTAssertEqual(LaserTrailElement.opacity(forAge: 0.25, life: 1), 0.75, accuracy: 1e-9)
        XCTAssertEqual(LaserTrailElement.opacity(forAge: 1, life: 1), 0)
        XCTAssertEqual(LaserTrailElement.opacity(forAge: 5, life: 1), 0)
        XCTAssertEqual(LaserTrailElement.opacity(forAge: -1, life: 1), 1)
        XCTAssertEqual(LaserTrailElement.opacity(forAge: 0, life: 0), 0)
    }

    func testBoundsCoverEveryPointPlusGlow() {
        let t = trail([(CGPoint(x: 10, y: 10), 0.5), (CGPoint(x: 90, y: 40), 0)])
        XCTAssertTrue(t.bounds.contains(CGPoint(x: 10, y: 10)))
        XCTAssertTrue(t.bounds.contains(CGPoint(x: 90, y: 40)))
        XCTAssertGreaterThan(t.bounds.width, 80)
    }

    func testEmptyTrailHasNullBoundsAndDrawsNothing() {
        XCTAssertTrue(trail([]).bounds.isNull)
    }

    func testEachFrameIsANewElementSoTheLayerRepaints() {
        XCTAssertNotEqual(trail([(.zero, 0)]), trail([(.zero, 0)]))
    }

    func testIsNeverHitByTheEraser() {
        XCTAssertFalse(trail([(.zero, 0), (CGPoint(x: 10, y: 10), 0)]).hitTest(CGPoint(x: 5, y: 5), tolerance: 20))
    }

    private func render(_ element: LaserTrailElement) -> (alphaSum: Int, redDominant: Bool) {
        let w = 120, h = 80
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        element.draw(in: ctx)
        let data = ctx.data!.assumingMemoryBound(to: UInt8.self)
        var alpha = 0, red = 0, other = 0
        for i in 0..<(w * h) {
            let a = Int(data[i * 4 + 3])
            alpha += a
            red += Int(data[i * 4]); other += Int(data[i * 4 + 1])
        }
        return (alpha, red > other)
    }

    func testDrawsARedTrailWhenFresh() {
        let r = render(trail([(CGPoint(x: 20, y: 40), 0.3), (CGPoint(x: 60, y: 40), 0.15), (CGPoint(x: 100, y: 40), 0)]))
        XCTAssertGreaterThan(r.alphaSum, 0)
        XCTAssertTrue(r.redDominant)
    }

    func testDrawsNothingOnceFullyFaded() {
        let r = render(trail([(CGPoint(x: 20, y: 40), 2), (CGPoint(x: 100, y: 40), 1.5)], life: 1))
        XCTAssertEqual(r.alphaSum, 0)
    }

    func testOlderPartsAreFainterThanNewerParts() {
        let faint = render(trail([(CGPoint(x: 20, y: 40), 0.9), (CGPoint(x: 100, y: 40), 0.85)]))
        let strong = render(trail([(CGPoint(x: 20, y: 40), 0.1), (CGPoint(x: 100, y: 40), 0.05)]))
        XCTAssertLessThan(faint.alphaSum, strong.alphaSum)
    }
}

@MainActor
final class LaserToolTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite = ""
    private var context: FakeToolContext!

    override func setUp() async throws {
        suite = "glaze.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        context = FakeToolContext()
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    private func p(_ x: CGFloat, _ y: CGFloat) -> InputPoint { InputPoint(location: CGPoint(x: x, y: y)) }

    private func makeTool(fade: TimeInterval = 0.2) -> LaserTool {
        let settings = ToolSettings(defaults: defaults)
        settings.setLaserFadeDuration(fade)
        return LaserTool(settings: settings)
    }

    func testHoveringShowsTheTrailWithoutAnyButtonPressed() {
        let tool = makeTool()
        tool.hover(p(10, 10), context: context)
        tool.hover(p(40, 20), context: context)
        XCTAssertTrue(tool.isShowing)
        XCTAssertTrue(context.lastLive is LaserTrailElement)
    }

    func testNothingIsEverCommittedToTheCanvas() {
        let tool = makeTool()
        tool.begin(p(0, 0), context: context)
        tool.move(p(30, 30), context: context)
        tool.end(p(60, 10), context: context)
        XCTAssertTrue(context.performed.isEmpty, "the laser must not create undo steps")
        XCTAssertTrue(context.canvas.isEmpty)
        tool.deactivate(context: context)
    }

    func testTinyMovesDoNotAddPoints() {
        let tool = makeTool()
        tool.hover(p(10, 10), context: context)
        let calls = context.liveCalls.count
        tool.hover(p(10.1, 10.1), context: context)
        XCTAssertEqual(context.liveCalls.count, calls)
        tool.deactivate(context: context)
    }

    func testDeactivateClearsTheTrailAtOnce() {
        let tool = makeTool(fade: 3)
        tool.hover(p(10, 10), context: context)
        tool.hover(p(80, 40), context: context)
        tool.deactivate(context: context)
        XCTAssertFalse(tool.isShowing)
        XCTAssertNil(context.lastLive)
    }

    func testTrailDisappearsShortlyAfterThePointerStops() async throws {
        let tool = makeTool(fade: 0.2)
        tool.hover(p(10, 10), context: context)
        tool.hover(p(60, 30), context: context)
        XCTAssertTrue(tool.isShowing)

        try await Task.sleep(for: .milliseconds(700))     // 0.2 s fade + generous slack for the timer

        XCTAssertFalse(tool.isShowing, "the trail should have faded away on its own")
        XCTAssertNil(context.lastLive, "and the live layer should have been emptied")
    }

    func testTrailStaysWhileThePointerKeepsMoving() async throws {
        let tool = makeTool(fade: 0.5)
        for i in 0..<8 {
            tool.hover(p(CGFloat(i) * 10, 5), context: context)
            try await Task.sleep(for: .milliseconds(30))
        }
        XCTAssertTrue(tool.isShowing)
        tool.deactivate(context: context)
    }

    func testFadeDurationFollowsTheSettings() {
        XCTAssertEqual(makeTool(fade: 1.5).fadeDuration, 1.5, accuracy: 1e-9)
        XCTAssertEqual(LaserTool().fadeDuration, BrushPresets.laser.fadeDuration ?? 0.8, accuracy: 1e-9)
    }

    func testHasItsOwnCursor() {
        let tool = makeTool()
        XCTAssertGreaterThan(tool.cursor.image.size.width, 10)
    }
}
