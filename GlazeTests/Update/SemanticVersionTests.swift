import XCTest
@testable import Glaze

final class SemanticVersionTests: XCTestCase {
    private func v(_ s: String) -> SemanticVersion { SemanticVersion(s)! }

    func testParsesWithAndWithoutLeadingV() {
        XCTAssertEqual(v("v1.2.3").components, [1, 2, 3])
        XCTAssertEqual(v("1.2.3").components, [1, 2, 3])
        XCTAssertEqual(v("V2").components, [2])
        XCTAssertEqual(v("0.1.0-beta.1").prerelease, "beta.1")
    }

    func testRejectsGarbage() {
        for bad in ["", "v", "abc", "1..2", "1.2.x", "1.2.3.4.5", "-beta", "1.2.-3"] {
            XCTAssertNil(SemanticVersion(bad), bad)
        }
    }

    func testOrdering() {
        XCTAssertLessThan(v("0.1.0"), v("0.2.0"))
        XCTAssertLessThan(v("0.9.0"), v("0.10.0"))
        XCTAssertLessThan(v("1.9.9"), v("2.0.0"))
        XCTAssertLessThan(v("1.0"), v("1.0.1"))
    }

    func testMissingPartsCountAsZero() {
        XCTAssertEqual(v("1.0"), v("1.0.0"))
        XCTAssertEqual(v("v1"), v("1.0.0.0"))
    }

    func testPrereleaseSortsBeforeRelease() {
        XCTAssertLessThan(v("1.0.0-beta.1"), v("1.0.0"))
        XCTAssertLessThan(v("1.0.0-beta.2"), v("1.0.0-beta.10"))
        XCTAssertLessThan(v("0.9.0"), v("1.0.0-beta.1"))
    }

    func testDescription() {
        XCTAssertEqual(v("v1.2").description, "1.2")
        XCTAssertEqual(v("1.0.0-rc.1").description, "1.0.0-rc.1")
    }
}
