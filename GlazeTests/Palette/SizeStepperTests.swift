import XCTest
@testable import Glaze

final class SizeStepperTests: XCTestCase {
    func testIncreaseFromLadderValueAndBetween() {
        XCTAssertEqual(SizeStepper.increased(4), 6)
        XCTAssertEqual(SizeStepper.increased(5), 6)
        XCTAssertEqual(SizeStepper.increased(0.2), 1)
    }

    func testDecreaseFromLadderValueAndBetween() {
        XCTAssertEqual(SizeStepper.decreased(6), 4)
        XCTAssertEqual(SizeStepper.decreased(7), 6)
        XCTAssertEqual(SizeStepper.decreased(500), 64)
    }

    func testClampsAtEnds() {
        XCTAssertEqual(SizeStepper.increased(64), 64)
        XCTAssertEqual(SizeStepper.decreased(1), 1)
        XCTAssertEqual(SizeStepper.clamped(-3), 1)
        XCTAssertEqual(SizeStepper.clamped(1000), 64)
    }
}
