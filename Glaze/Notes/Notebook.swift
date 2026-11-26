import Foundation

/// One page of the notepad: typed text plus ink drawn over it.
struct NotePage: Codable, Equatable, Identifiable {
    var id = UUID()
    var text = ""
    var strokes: [NoteStrokeRecord] = []
    var modified = Date()

    var isEmpty: Bool { text.isEmpty && strokes.isEmpty }
}

/// The pages and which one is showing. Pure value type: every operation keeps at least one
/// page and a valid `selectedIndex`, so the UI never has to guard against an empty notebook.
struct Notebook: Codable, Equatable {
    static let currentVersion = 1

    var version = Notebook.currentVersion
    private(set) var pages: [NotePage]
    private(set) var selectedIndex: Int

    init(pages: [NotePage] = [NotePage()], selectedIndex: Int = 0) {
        self.pages = pages.isEmpty ? [NotePage()] : pages
        self.selectedIndex = min(max(selectedIndex, 0), self.pages.count - 1)
    }

    private enum CodingKeys: String, CodingKey { case version, pages, selectedIndex }

    /// Decoding goes through the same normalisation as `init(pages:selectedIndex:)`, so a damaged
    /// or hand-edited file can't produce an empty notebook or an out-of-range selection.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try c.decodeIfPresent([NotePage].self, forKey: .pages) ?? []
        self.init(pages: decoded, selectedIndex: try c.decodeIfPresent(Int.self, forKey: .selectedIndex) ?? 0)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Notebook.currentVersion
    }

    var currentPage: NotePage { pages[selectedIndex] }
    var pageCount: Int { pages.count }
    var canGoPrevious: Bool { selectedIndex > 0 }
    var canGoNext: Bool { selectedIndex < pages.count - 1 }

    // MARK: Navigation

    mutating func goPrevious() { if canGoPrevious { selectedIndex -= 1 } }
    mutating func goNext() { if canGoNext { selectedIndex += 1 } }

    /// Adds an empty page right after the current one and shows it.
    mutating func addPage() {
        pages.insert(NotePage(), at: selectedIndex + 1)
        selectedIndex += 1
    }

    /// Deletes the current page. The last remaining page is emptied instead of removed.
    /// Returns the id of the page that was deleted or emptied.
    @discardableResult
    mutating func deleteCurrentPage() -> UUID {
        let removed = pages[selectedIndex].id
        if pages.count == 1 {
            pages[0] = NotePage()
        } else {
            pages.remove(at: selectedIndex)
            selectedIndex = min(selectedIndex, pages.count - 1)
        }
        return removed
    }

    // MARK: Editing

    mutating func setText(_ text: String, forPage id: UUID, at date: Date = Date()) {
        guard let i = pages.firstIndex(where: { $0.id == id }), pages[i].text != text else { return }
        pages[i].text = text
        pages[i].modified = date
    }

    mutating func setStrokes(_ strokes: [NoteStrokeRecord], forPage id: UUID, at date: Date = Date()) {
        guard let i = pages.firstIndex(where: { $0.id == id }) else { return }
        pages[i].strokes = strokes
        pages[i].modified = date
    }
}
