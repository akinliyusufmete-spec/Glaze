import Foundation
import Observation

/// What the notepad is doing right now and the pages behind it. Owns one `CanvasStore` per page
/// (so each page has its own ink and undo history) and saves the notebook as it changes.
@MainActor
@Observable
final class NotepadModel {
    enum Mode: Equatable {
        case type
        case draw(ToolID)

        var tool: ToolID? {
            if case let .draw(tool) = self { return tool }
            return nil
        }
    }

    /// Every page's ink lives on this one display id in its own store.
    static let inkDisplayID: CanvasStore.DisplayID = 1
    /// How long after the last change the notebook is written to disk.
    static let saveDelay: Duration = .milliseconds(600)

    private(set) var notebook: Notebook
    var mode: Mode = .type
    /// Bumped whenever ink changes, so views that show undo/redo availability refresh.
    private(set) var inkRevision = 0

    let registry: ToolRegistry

    @ObservationIgnored private let storage: NotebookStorage
    @ObservationIgnored private var inkStores: [UUID: CanvasStore] = [:]
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(storage: NotebookStorage, registry: ToolRegistry) {
        self.storage = storage
        self.registry = registry
        notebook = storage.load()
    }

    var currentPage: NotePage { notebook.currentPage }

    // MARK: Ink

    /// The store for a page's ink, loading its saved strokes the first time it's asked for.
    func inkStore(for pageID: UUID) -> CanvasStore {
        if let store = inkStores[pageID] { return store }
        let store = CanvasStore()
        if let page = notebook.pages.first(where: { $0.id == pageID }) {
            store.load(page.strokes.map { $0.makeStroke() }, on: Self.inkDisplayID)
        }
        store.onChange = { [weak self] _ in self?.inkChanged(on: pageID) }
        inkStores[pageID] = store
        return store
    }

    var canUndoInk: Bool { _ = inkRevision; return inkStore(for: currentPage.id).canUndo(on: Self.inkDisplayID) }
    var canRedoInk: Bool { _ = inkRevision; return inkStore(for: currentPage.id).canRedo(on: Self.inkDisplayID) }

    func undoInk() { inkStore(for: currentPage.id).undo(on: Self.inkDisplayID) }
    func redoInk() { inkStore(for: currentPage.id).redo(on: Self.inkDisplayID) }

    /// Wipes the current page's ink as one undoable step. Text is left alone.
    func clearInk() {
        let store = inkStore(for: currentPage.id)
        let canvas = store.canvas(for: Self.inkDisplayID)
        guard !canvas.isEmpty else { return }
        store.perform(ClearCanvas(canvas: canvas), on: Self.inkDisplayID)
    }

    private func inkChanged(on pageID: UUID) {
        guard let store = inkStores[pageID] else { return }
        let strokes = store.canvas(for: Self.inkDisplayID).elements
            .compactMap { $0 as? StrokeElement }
            .map(NoteStrokeRecord.init)
        notebook.setStrokes(strokes, forPage: pageID)
        inkRevision += 1
        scheduleSave()
    }

    // MARK: Text

    func setText(_ text: String, forPage id: UUID) {
        notebook.setText(text, forPage: id)
        scheduleSave()
    }

    // MARK: Pages

    func goPrevious() { notebook.goPrevious(); scheduleSave() }
    func goNext() { notebook.goNext(); scheduleSave() }
    func addPage() { notebook.addPage(); scheduleSave() }

    func deleteCurrentPage() {
        let removed = notebook.deleteCurrentPage()
        inkStores[removed] = nil
        inkRevision += 1
        scheduleSave()
    }

    // MARK: Saving

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// Writes the notebook now (closing the pad, quitting).
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        do { try storage.save(notebook) } catch { NSLog("Glaze: couldn't save notebook: \(error.localizedDescription)") }
    }
}
