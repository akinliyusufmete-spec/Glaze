import Foundation

/// Saves and loads the notebook as one JSON file.
struct NotebookStorage {
    let url: URL

    /// `~/Library/Application Support/Glaze/notebook.json`
    static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Glaze", isDirectory: true).appendingPathComponent("notebook.json")
    }

    /// The saved notebook, or an empty one when there is no file yet or it can't be read.
    // DECISION: an unreadable file is moved aside (not overwritten) so a bad save or a newer
    // app version's format never silently destroys the user's notes.
    func load() -> Notebook {
        guard let data = try? Data(contentsOf: url) else { return Notebook() }
        if let notebook = try? JSONDecoder().decode(Notebook.self, from: data),
           notebook.version <= Notebook.currentVersion {
            return notebook
        }
        let backup = url.deletingPathExtension().appendingPathExtension("unreadable-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: url, to: backup)
        return Notebook()
    }

    func save(_ notebook: Notebook) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(notebook).write(to: url, options: .atomic)
    }
}
