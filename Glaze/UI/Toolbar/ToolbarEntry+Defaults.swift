import Foundation

/// Ids of the toolbar's action buttons.
enum ToolbarActionID {
    static let undo = "undo"
    static let redo = "redo"
    static let clear = "clear"
    static let sizeDown = "sizeDown"
    static let sizeUp = "sizeUp"
    static let notepad = "notepad"
}

extension ToolbarEntry {
    /// The toolbar's contents. Tool entry ids are `ToolID.rawValue`s. Tools that don't exist
    /// yet (shapes, laser, image) are added by the phase that builds them.
    static let defaults: [ToolbarEntry] = [
        ToolbarEntry(id: ToolID.pen.rawValue, title: "Pen", symbol: "pencil.tip", fallbackSymbol: "pencil", shortcutHint: "P"),
        ToolbarEntry(id: ToolID.marker.rawValue, title: "Marker", symbol: "paintbrush.pointed", fallbackSymbol: "paintbrush", shortcutHint: "M"),
        ToolbarEntry(id: ToolID.highlighter.rawValue, title: "Highlighter", symbol: "highlighter", fallbackSymbol: "paintbrush", shortcutHint: "H"),
        ToolbarEntry(id: ToolID.pencil.rawValue, title: "Pencil", symbol: "pencil", fallbackSymbol: "pencil.line"),
        ToolbarEntry(id: ToolID.calligraphy.rawValue, title: "Calligraphy", symbol: "signature", fallbackSymbol: "pencil.line"),
        ToolbarEntry(id: ToolID.neon.rawValue, title: "Neon", symbol: "sparkles", fallbackSymbol: "star"),
        ToolbarEntry(id: ToolID.dashed.rawValue, title: "Dashed", symbol: "scribble", fallbackSymbol: "line.diagonal"),
        ToolbarEntry(id: ToolID.eraser.rawValue, title: "Eraser", symbol: "eraser", fallbackSymbol: "xmark.circle", shortcutHint: "E"),
        .separator("sep-size"),
        ToolbarEntry(id: ToolbarActionID.sizeDown, kind: .action, title: "Smaller", symbol: "minus.circle", shortcutHint: "["),
        ToolbarEntry(id: ToolbarActionID.sizeUp, kind: .action, title: "Larger", symbol: "plus.circle", shortcutHint: "]"),
        .separator("sep-history"),
        ToolbarEntry(id: ToolbarActionID.undo, kind: .action, title: "Undo", symbol: "arrow.uturn.backward", shortcutHint: "⌘Z"),
        ToolbarEntry(id: ToolbarActionID.redo, kind: .action, title: "Redo", symbol: "arrow.uturn.forward", shortcutHint: "⇧⌘Z"),
        ToolbarEntry(id: ToolbarActionID.clear, kind: .action, title: "Clear", symbol: "trash", shortcutHint: "⌥⌘K"),
        .separator("sep-notepad"),
        ToolbarEntry(id: ToolbarActionID.notepad, kind: .action, title: "Notepad", symbol: "note.text",
                     fallbackSymbol: "square.and.pencil", shortcutHint: "⌥⌘N"),
    ]
}
