import XCTest
@testable import Glaze

final class ColorHSBTests: XCTestCase {
    func testPrimaries() throws {
        let red = try XCTUnwrap(RGBAColor(hex: "#FF0000")).hsb
        XCTAssertEqual(red, HSBColor(h: 0, s: 1, b: 1))
        XCTAssertEqual(try XCTUnwrap(RGBAColor(hex: "#00FF00")).hsb.h, 1.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(RGBAColor(hex: "#0000FF")).hsb.h, 2.0 / 3, accuracy: 1e-9)
    }

    func testGrayHasZeroSaturation() throws {
        let hsb = try XCTUnwrap(RGBAColor(hex: "#808080")).hsb
        XCTAssertEqual(hsb.s, 0)
        XCTAssertEqual(hsb.b, 128.0 / 255, accuracy: 1e-9)
    }

    func testBlackHasZeroBrightness() throws {
        XCTAssertEqual(try XCTUnwrap(RGBAColor(hex: "#000000")).hsb.b, 0)
    }

    func testRoundTripThroughHSB() throws {
        for hex in ["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#0A84FF", "#5E5CE6", "#123456", "#FFFFFF"] {
            let c = try XCTUnwrap(RGBAColor(hex: hex))
            XCTAssertEqual(RGBAColor(hsb: c.hsb).hexString(), hex, hex)
        }
    }

    func testHueWrapsAndAlphaCarries() {
        let a = RGBAColor(hsb: HSBColor(h: 1.0, s: 1, b: 1))
        let b = RGBAColor(hsb: HSBColor(h: 0.0, s: 1, b: 1))
        XCTAssertEqual(a.hexString(), b.hexString())
        XCTAssertEqual(RGBAColor(hsb: HSBColor(h: 0.5, s: 1, b: 1), alpha: 0.25).a, 0.25)
    }
}
