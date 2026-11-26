import XCTest
@testable import Glaze

final class ReleaseInfoTests: XCTestCase {
    static func json(tag: String = "v0.2.0", assets: String = """
        [{"name":"Glaze-0.2.0.zip","browser_download_url":"https://example.com/Glaze-0.2.0.zip"},
         {"name":"Glaze-0.2.0.dmg","browser_download_url":"https://example.com/Glaze-0.2.0.dmg"},
         {"name":"SHA256SUMS.txt","browser_download_url":"https://example.com/SHA256SUMS.txt"}]
        """) -> Data {
        Data("""
        {"tag_name":"\(tag)","html_url":"https://github.com/o/r/releases/tag/\(tag)",
         "body":"Notes here","assets":\(assets)}
        """.utf8)
    }

    func testParsesVersionPageAndNotes() throws {
        let r = try ReleaseInfo.parse(Self.json())
        XCTAssertEqual(r.version, SemanticVersion("0.2.0"))
        XCTAssertEqual(r.tag, "v0.2.0")
        XCTAssertEqual(r.pageURL.absoluteString, "https://github.com/o/r/releases/tag/v0.2.0")
        XCTAssertEqual(r.notes, "Notes here")
    }

    func testPrefersTheDMGOverTheZip() throws {
        XCTAssertEqual(try ReleaseInfo.parse(Self.json()).downloadURL?.lastPathComponent, "Glaze-0.2.0.dmg")
    }

    func testFallsBackToZipThenNil() throws {
        let zipOnly = Self.json(assets: #"[{"name":"a.zip","browser_download_url":"https://example.com/a.zip"}]"#)
        XCTAssertEqual(try ReleaseInfo.parse(zipOnly).downloadURL?.lastPathComponent, "a.zip")
        XCTAssertNil(try ReleaseInfo.parse(Self.json(assets: "[]")).downloadURL)
    }

    func testRejectsBadInput() {
        XCTAssertThrowsError(try ReleaseInfo.parse(Data("nope".utf8)))
        XCTAssertThrowsError(try ReleaseInfo.parse(Self.json(tag: "nightly"))) { error in
            XCTAssertEqual(error as? ReleaseInfo.ParseError, .notAVersion("nightly"))
        }
    }
}
