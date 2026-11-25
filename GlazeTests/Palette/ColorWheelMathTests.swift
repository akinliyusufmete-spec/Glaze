import XCTest
import CoreGraphics
@testable import Glaze

final class ColorWheelMathTests: XCTestCase {
    private let center = CGPoint(x: 100, y: 100)
    private let radius: CGFloat = 50

    func testCardinalDirections() {
        let right = ColorWheelMath.hueSaturation(at: CGPoint(x: 150, y: 100), center: center, radius: radius)
        XCTAssertEqual(right.hue, 0, accuracy: 1e-9)
        XCTAssertEqual(right.saturation, 1, accuracy: 1e-9)

        let down = ColorWheelMath.hueSaturation(at: CGPoint(x: 100, y: 125), center: center, radius: radius)
        XCTAssertEqual(down.hue, 0.25, accuracy: 1e-9)
        XCTAssertEqual(down.saturation, 0.5, accuracy: 1e-9)

        let left = ColorWheelMath.hueSaturation(at: CGPoint(x: 50, y: 100), center: center, radius: radius)
        XCTAssertEqual(left.hue, 0.5, accuracy: 1e-9)

        let up = ColorWheelMath.hueSaturation(at: CGPoint(x: 100, y: 50), center: center, radius: radius)
        XCTAssertEqual(up.hue, 0.75, accuracy: 1e-9)
    }

    func testSaturationClampsOutsideRadius() {
        let r = ColorWheelMath.hueSaturation(at: CGPoint(x: 400, y: 100), center: center, radius: radius)
        XCTAssertEqual(r.saturation, 1)
    }

    func testCenterAndZeroRadius() {
        XCTAssertEqual(ColorWheelMath.hueSaturation(at: center, center: center, radius: radius).saturation, 0)
        let z = ColorWheelMath.hueSaturation(at: CGPoint(x: 5, y: 5), center: center, radius: 0)
        XCTAssertEqual(z.saturation, 0)
    }

    func testPointRoundTrip() {
        for hue in stride(from: 0.0, to: 1.0, by: 0.1) {
            let p = ColorWheelMath.point(hue: hue, saturation: 0.6, center: center, radius: radius)
            let back = ColorWheelMath.hueSaturation(at: p, center: center, radius: radius)
            XCTAssertEqual(back.hue, hue, accuracy: 1e-6)
            XCTAssertEqual(back.saturation, 0.6, accuracy: 1e-6)
        }
    }
}
