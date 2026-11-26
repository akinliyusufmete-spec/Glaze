import XCTest
@testable import Glaze

final class ColorHexTests: XCTestCase {
    func testParsesSixDigit() throws {
        let c = try XCTUnwrap(RGBAColor(hex: "#FF8000"))
        XCTAssertEqual(c.r, 1, accuracy: 1e-9)
        XCTAssertEqual(c.g, 128.0 / 255, accuracy: 1e-9)
        XCTAssertEqual(c.b, 0, accuracy: 1e-9)
        XCTAssertEqual(c.a, 1, accuracy: 1e-9)
    }

    func testParsesShortAndAlphaForms() throws {
        XCTAssertEqual(RGBAColor(hex: "f80")?.hexString(), "#FF8800")
        XCTAssertEqual(RGBAColor(hex: "#f808")?.hexString(includeAlpha: true), "#FF880088")
        XCTAssertEqual(RGBAColor(hex: "#11223344")?.hexString(includeAlpha: true), "#11223344")
    }

    func testRejectsInvalid() {
        for bad in ["", "#", "#12", "#12345", "#GGGGGG", "#1234567", "12 34 56"] {
            XCTAssertNil(RGBAColor(hex: bad), bad)
        }
    }

    func testRoundTrip() {
        for hex in ["#000000", "#FFFFFF", "#0A84FF", "#34C759"] {
            XCTAssertEqual(RGBAColor(hex: hex)?.hexString(), hex)
        }
    }
}
