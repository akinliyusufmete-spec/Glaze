import XCTest
@testable import Glaze

final class PressureCurveTests: XCTestCase {
    func testNoneIgnoresPressure() {
        XCTAssertEqual(PressureCurve.none.scale(for: 0), 1)
        XCTAssertEqual(PressureCurve.none.scale(for: 0.5), 1)
    }

    func testLinearIsProportionalWithFloor() {
        XCTAssertEqual(PressureCurve.linear.scale(for: 0.5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(PressureCurve.linear.scale(for: 0), PressureCurve.minimumScale)
        XCTAssertEqual(PressureCurve.linear.scale(for: 2), 1, "clamped to 0…1")
    }

    func testEaseExponentShapesResponse() {
        let light = PressureCurve.ease(exponent: 0.5).scale(for: 0.25)
        let strong = PressureCurve.ease(exponent: 2).scale(for: 0.5)
        XCTAssertEqual(light, 0.5, accuracy: 1e-9)
        XCTAssertEqual(strong, 0.25, accuracy: 1e-9)
        XCTAssertEqual(PressureCurve.ease(exponent: 2).scale(for: 1), 1)
    }
}

final class TaperTests: XCTestCase {
    func testNoTaperIsFullWidth() {
        XCTAssertEqual(Taper.none.scale(at: 0, length: 100), 1)
        XCTAssertEqual(Taper.none.scale(at: 100, length: 100), 1)
    }

    func testEndsAreNarrowAndMiddleIsFull() {
        let taper = Taper(start: 10, end: 20)
        XCTAssertEqual(taper.scale(at: 0, length: 100), Taper.minimumScale)
        XCTAssertEqual(taper.scale(at: 100, length: 100), Taper.minimumScale)
        XCTAssertEqual(taper.scale(at: 50, length: 100), 1)
        XCTAssertLessThan(taper.scale(at: 90, length: 100), 1)
        XCTAssertEqual(taper.scale(at: 79, length: 100), 1)
    }

    func testTaperIsCappedAtHalfOfShortStrokes() {
        let taper = Taper(start: 50, end: 50)
        XCTAssertEqual(taper.scale(at: 5, length: 10), 1, accuracy: 1e-9)
        XCTAssertEqual(taper.scale(at: 0, length: 1), 1, "strokes under 2 pt don't taper")
    }
}

final class TiltResponseTests: XCTestCase {
    func testZeroTiltChangesNothing() {
        for response: TiltResponse in [.none, .widen(factor: 1.5), .rotateNib] {
            XCTAssertEqual(response.widthScale(for: .zero), 1)
            XCTAssertEqual(response.nibAngle(base: 0.7, tilt: .zero), 0.7)
        }
    }

    func testWidenGrowsWithTiltAndSaturates() {
        let widen = TiltResponse.widen(factor: 1.5)
        XCTAssertEqual(widen.widthScale(for: CGVector(dx: 0.5, dy: 0)), 1.75, accuracy: 1e-9)
        XCTAssertEqual(widen.widthScale(for: CGVector(dx: 3, dy: 4)), 2.5, accuracy: 1e-9)
    }

    func testRotateNibFollowsTiltAboveThreshold() {
        let rotate = TiltResponse.rotateNib
        XCTAssertEqual(rotate.nibAngle(base: 0.7, tilt: CGVector(dx: 0.1, dy: 0)), 0.7)
        XCTAssertEqual(rotate.nibAngle(base: 0.7, tilt: CGVector(dx: 0, dy: 0.5)), .pi, accuracy: 1e-9)
        XCTAssertEqual(TiltResponse.none.nibAngle(base: 0.7, tilt: CGVector(dx: 0, dy: 0.5)), 0.7)
    }
}
