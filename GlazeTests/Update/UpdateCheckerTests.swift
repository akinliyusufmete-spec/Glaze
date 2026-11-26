import XCTest
@testable import Glaze

@MainActor
final class UpdateCheckerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUp() {
        suite = "glaze.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private func checker(
        current: String, now: @escaping () -> Date = Date.init,
        fetch: @escaping @Sendable () async throws -> Data
    ) -> UpdateChecker {
        UpdateChecker(currentVersion: SemanticVersion(current)!, defaults: defaults, now: now, fetch: fetch)
    }

    func testNewerReleaseIsAvailable() async {
        let c = checker(current: "0.1.0") { ReleaseInfoTests.json(tag: "v0.2.0") }
        await c.check()
        guard case let .available(release) = c.state else { return XCTFail("\(c.state)") }
        XCTAssertEqual(release.version, SemanticVersion("0.2.0"))
    }

    func testSameOrOlderReleaseIsUpToDate() async {
        let same = checker(current: "0.2.0") { ReleaseInfoTests.json(tag: "v0.2.0") }
        await same.check()
        XCTAssertEqual(same.state, .upToDate)

        let older = checker(current: "1.0.0") { ReleaseInfoTests.json(tag: "v0.2.0") }
        await older.check()
        XCTAssertEqual(older.state, .upToDate)
    }

    func testNoPublishedReleaseCountsAsUpToDate() async {
        let c = checker(current: "0.1.0") { throw UpdateChecker.UpdateError.noReleases }
        await c.check()
        XCTAssertEqual(c.state, .upToDate)
    }

    func testNetworkAndParseFailuresReportFailed() async {
        let http = checker(current: "0.1.0") { throw UpdateChecker.UpdateError.http(503) }
        await http.check()
        XCTAssertEqual(http.state, .failed("GitHub returned HTTP 503"))

        let junk = checker(current: "0.1.0") { Data("junk".utf8) }
        await junk.check()
        XCTAssertEqual(junk.state, .failed("Couldn't read the latest release"))
    }

    func testCheckIfDueRunsOncePerInterval() async {
        var clock = Date(timeIntervalSince1970: 1_000_000)
        let calls = CallCounter()
        let c = checker(current: "0.1.0", now: { clock }) {
            await calls.bump()
            return ReleaseInfoTests.json(tag: "v0.1.0")
        }
        await c.checkIfDue()
        await c.checkIfDue()
        var count = await calls.value
        XCTAssertEqual(count, 1, "second launch the same day must not hit the network")

        clock = clock.addingTimeInterval(UpdateChecker.interval + 1)
        await c.checkIfDue()
        count = await calls.value
        XCTAssertEqual(count, 2)
    }
}

private actor CallCounter {
    private(set) var value = 0
    func bump() { value += 1 }
}
