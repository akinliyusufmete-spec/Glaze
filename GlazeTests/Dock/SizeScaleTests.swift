import XCTest
@testable import Glaze

final class SizeScaleTests: XCTestCase {
    func testEndpoints() {
        XCTAssertEqual(SizeScale.size(forFraction: 0), SizeStepper.minimum)
        XCTAssertEqual(SizeScale.size(forFraction: 1), SizeStepper.maximum)
        XCTAssertEqual(SizeScale.fraction(forSize: SizeStepper.minimum), 0, accuracy: 1e-12)
        XCTAssertEqual(SizeScale.fraction(forSize: SizeStepper.maximum), 1, accuracy: 1e-12)
    }

    func testMiddleOfTheSliderIsTheGeometricMean() {
        XCTAssertEqual(SizeScale.size(forFraction: 0.5), 8, accuracy: 0.01)    // sqrt(1 * 64)
    }

    func testClampsOutOfRange() {
        XCTAssertEqual(SizeScale.size(forFraction: -1), SizeStepper.minimum)
        XCTAssertEqual(SizeScale.size(forFraction: 7), SizeStepper.maximum)
        XCTAssertEqual(SizeScale.fraction(forSize: 0.1), 0)
        XCTAssertEqual(SizeScale.fraction(forSize: 1000), 1)
    }

    func testMonotonic() {
        var last = 0.0
        for i in 0...100 {
            let s = SizeScale.size(forFraction: Double(i) / 100)
            XCTAssertGreaterThanOrEqual(s, last)
            last = s
        }
    }

    func testRoundTripStaysClose() {
        for size in [1.0, 2, 3, 6, 12, 24, 48, 64] {
            let back = SizeScale.size(forFraction: SizeScale.fraction(forSize: size))
            XCTAssertEqual(back, size, accuracy: max(0.5, size * 0.03), "\(size)")
        }
    }

    func testSizesAreWholeOrHalfPoints() {
        for i in 0...200 {
            let s = SizeScale.size(forFraction: Double(i) / 200)
            XCTAssertEqual(s * 2, (s * 2).rounded(), accuracy: 1e-9)
        }
    }

    func testThinSizesGetMoreRoomThanALinearSliderWould() {
        // On a linear 1…64 slider, 1…8 would fill 11% of the track; here it's half.
        XCTAssertEqual(SizeScale.fraction(forSize: 8), 0.5, accuracy: 0.01)
    }
}
