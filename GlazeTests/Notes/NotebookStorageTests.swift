import XCTest
@testable import Glaze

final class NotebookStorageTests: XCTestCase {
    private var dir: URL!
    private var storage: NotebookStorage!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("glaze-tests-\(UUID().uuidString)")
        storage = NotebookStorage(url: dir.appendingPathComponent("nested/notebook.json"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testMissingFileGivesAnEmptyNotebook() {
        XCTAssertEqual(storage.load().pageCount, 1)
        XCTAssertTrue(storage.load().currentPage.isEmpty)
    }

    func testSaveCreatesFoldersAndRoundTrips() throws {
        var n = Notebook()
        n.setText("remember the milk", forPage: n.currentPage.id)
        n.addPage()
        try storage.save(n)
        XCTAssertEqual(storage.load(), n)
    }

    func testUnreadableFileIsMovedAsideNotOverwritten() throws {
        try FileManager.default.createDirectory(at: storage.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: storage.url)
        XCTAssertTrue(storage.load().currentPage.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.url.path))
        let kept = try FileManager.default.contentsOfDirectory(atPath: storage.url.deletingLastPathComponent().path)
        XCTAssertEqual(kept.filter { $0.contains("unreadable") }.count, 1)
    }

    func testNewerFormatIsMovedAsideToo() throws {
        try FileManager.default.createDirectory(at: storage.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"version":99,"pages":[],"selectedIndex":0}"#.utf8).write(to: storage.url)
        _ = storage.load()
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.url.path))
    }
}
