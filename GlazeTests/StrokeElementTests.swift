import XCTest
@testable import Glaze

final class StrokeElementTests: XCTestCase {
    func testBoundsPadByHalfWidthPlusOne() {
        let stroke = Fixtures.line(x0: 0, x1: 100, y: 50, width: 4)
        XCTAssertEqual(stroke.bounds, CGRect(x: -3, y: 47, width: 106, height: 6))
    }

    func testBoundsFollowTransform() {
        let stroke = StrokeElement(
            points: [.zero, CGPoint(x: 10, y: 0)], color: Fixtures.red, width: 2,
            transform: CGAffineTransform(translationX: 100, y: 200)
        )
        XCTAssertEqual(stroke.bounds, CGRect(x: 98, y: 198, width: 14, height: 4))
    }

    func testEmptyStrokeHasNullBoundsAndNeverHits() {
        let stroke = StrokeElement(points: [], color: Fixtures.red, width: 4)
        XCTAssertTrue(stroke.bounds.isNull)
        XCTAssertFalse(stroke.hitTest(.zero, tolerance: 100))
    }

    func testHitTestUsesHalfWidthPlusTolerance() {
        let stroke = Fixtures.line(width: 4) // reach = 2 + tolerance
        XCTAssertTrue(stroke.hitTest(CGPoint(x: 50, y: 4.9), tolerance: 3))
        XCTAssertFalse(stroke.hitTest(CGPoint(x: 50, y: 5.1), tolerance: 3))
        XCTAssertTrue(stroke.hitTest(CGPoint(x: 103, y: 0), tolerance: 1))
        XCTAssertFalse(stroke.hitTest(CGPoint(x: 104, y: 0), tolerance: 1))
    }

    func testHitTestRespectsTransform() {
        let stroke = StrokeElement(
            points: [.zero, CGPoint(x: 10, y: 0)], color: Fixtures.red, width: 2,
            transform: CGAffineTransform(translationX: 100, y: 0)
        )
        XCTAssertTrue(stroke.hitTest(CGPoint(x: 105, y: 0), tolerance: 0))
        XCTAssertFalse(stroke.hitTest(CGPoint(x: 5, y: 0), tolerance: 0))
    }

    func testIdentityIsByID() {
        let id = UUID()
        let a = StrokeElement(id: id, points: [.zero], color: Fixtures.red, width: 1)
        let b = StrokeElement(id: id, points: [.zero, CGPoint(x: 9, y: 9)], color: Fixtures.red, width: 8)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, Fixtures.line())
    }
}
