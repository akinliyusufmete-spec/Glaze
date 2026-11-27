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
    /// yet (shapes, image) are added by the phase that builds them. Brush size is a slider the
    /// toolbar draws itself, not an entry.
    static let defaults: [ToolbarEntry] = [
        ToolbarEntry(id: ToolID.pen.rawValue, title: "Pen", detail: "Thin, smooth freehand line.",
                     symbol: "pencil.tip", fallbackSymbol: "pencil", shortcutAction: "toolPen"),
        ToolbarEntry(id: ToolID.marker.rawValue, title: "Marker", detail: "Thick marker with flat ends.",
                     symbol: "paintbrush.pointed", fallbackSymbol: "paintbrush", shortcutAction: "toolMarker"),
        ToolbarEntry(id: ToolID.highlighter.rawValue, title: "Highlighter",
                     detail: "Wide see-through highlighter that straightens near-straight lines.",
                     symbol: "highlighter", fallbackSymbol: "paintbrush", shortcutAction: "toolHighlighter"),
        ToolbarEntry(id: ToolID.pencil.rawValue, title: "Pencil", detail: "Textured pencil that reacts to pressure.",
                     symbol: "pencil", fallbackSymbol: "pencil.line", shortcutAction: "toolPencil"),
        ToolbarEntry(id: ToolID.calligraphy.rawValue, title: "Calligraphy",
                     detail: "Angled nib whose width follows the stroke direction.",
                     symbol: "signature", fallbackSymbol: "pencil.line", shortcutAction: "toolCalligraphy"),
        ToolbarEntry(id: ToolID.neon.rawValue, title: "Neon", detail: "Glowing line with a bright core. Stays on screen.",
                     symbol: "sparkles", fallbackSymbol: "star", shortcutAction: "toolNeon"),
        ToolbarEntry(id: ToolID.dashed.rawValue, title: "Dashed", detail: "Dashed line.",
                     symbol: "scribble", fallbackSymbol: "line.diagonal", shortcutAction: "toolDashed"),
        ToolbarEntry(id: ToolID.eraser.rawValue, title: "Eraser", detail: "Erase whole strokes by touching them.",
                     symbol: "eraser", fallbackSymbol: "xmark.circle", shortcutAction: "toolEraser"),
        ToolbarEntry(id: ToolID.laser.rawValue, title: "Laser pointer",
                     detail: "A red laser dot with a trail that fades when you stop moving. Nothing is saved.",
                     symbol: "cursorarrow.rays", fallbackSymbol: "scope", shortcutAction: "toolLaser"),
        .separator("sep-history"),
        ToolbarEntry(id: ToolbarActionID.undo, kind: .action, title: "Undo", detail: "Undo the last stroke on this display.",
                     symbol: "arrow.uturn.backward", shortcutAction: "undo"),
        ToolbarEntry(id: ToolbarActionID.redo, kind: .action, title: "Redo", detail: "Bring back the stroke you undid.",
                     symbol: "arrow.uturn.forward", shortcutAction: "redo"),
        ToolbarEntry(id: ToolbarActionID.clear, kind: .action, title: "Clear",
                     detail: "Clear the drawings on the display under the pointer. Undoable.",
                     symbol: "trash", shortcutAction: "clearDisplay"),
        .separator("sep-notepad"),
        ToolbarEntry(id: ToolbarActionID.notepad, kind: .action, title: "Notepad", detail: "Open or close the notepad.",
                     symbol: "note.text", fallbackSymbol: "square.and.pencil", shortcutAction: "toggleNotepad"),
    ]
}
