import KeyboardShortcuts

/// One rebindable action. The catalog is the single list the hover hints and the Shortcuts
/// settings tab both read, so what a hint says is always what the Settings tab shows.
struct ShortcutAction: Identifiable {
    enum Scope {
        /// Works in any app, so its default uses modifier keys.
        case global
        /// Only registered while Draw mode is on, so plain keys never hijack typing elsewhere.
        case drawing
    }

    let id: String
    let title: String
    let detail: String
    let scope: Scope
    let name: KeyboardShortcuts.Name

    /// The binding as text (e.g. "⌥⌘D"), or `nil` when the user cleared it.
    var shortcutText: String? {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else { return nil }
        let text = shortcut.description.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }
}

enum ShortcutCatalog {
    static let all: [ShortcutAction] = {
        var list: [ShortcutAction] = [
        // Global
            ShortcutAction(id: "toggleDraw", title: "Draw mode", detail: "Switch between Pointer and Draw mode.", scope: .global, name: .toggleDraw),
            ShortcutAction(id: "toggleLaser", title: "Laser pointer", detail: "Turn the laser pointer on or off.", scope: .global, name: .toggleLaser),
            ShortcutAction(id: "toggleNotepad", title: "Notepad", detail: "Open or close the notepad.", scope: .global, name: .toggleNotepad),
            ShortcutAction(id: "toggleToolbar", title: "Toolbar", detail: "Show or hide the toolbar.", scope: .global, name: .toggleToolbar),
            ShortcutAction(id: "toggleColorPanel", title: "Color panel", detail: "Open or close the color panel.", scope: .global, name: .toggleColorPanel),
            ShortcutAction(id: "clearDisplay", title: "Clear drawings", detail: "Clear the drawings on the display under the pointer. Undoable.", scope: .global, name: .clearDisplay),
        // Drawing
            ShortcutAction(id: "exitDraw", title: "Leave Draw mode", detail: "Go back to Pointer mode.", scope: .drawing, name: .exitDraw),
            ShortcutAction(id: "undo", title: "Undo", detail: "Undo the last stroke on this display.", scope: .drawing, name: .undo),
            ShortcutAction(id: "redo", title: "Redo", detail: "Bring back the stroke you undid.", scope: .drawing, name: .redo),
            ShortcutAction(id: "toolPen", title: "Pen", detail: "Thin, smooth freehand line.", scope: .drawing, name: .toolPen),
            ShortcutAction(id: "toolMarker", title: "Marker", detail: "Thick marker with flat ends.", scope: .drawing, name: .toolMarker),
            ShortcutAction(id: "toolHighlighter", title: "Highlighter", detail: "Wide see-through highlighter that straightens near-straight lines.", scope: .drawing, name: .toolHighlighter),
            ShortcutAction(id: "toolPencil", title: "Pencil", detail: "Textured pencil that reacts to pressure.", scope: .drawing, name: .toolPencil),
            ShortcutAction(id: "toolCalligraphy", title: "Calligraphy", detail: "Angled nib whose width follows the stroke direction.", scope: .drawing, name: .toolCalligraphy),
            ShortcutAction(id: "toolNeon", title: "Neon", detail: "Glowing line with a bright core. Stays on screen.", scope: .drawing, name: .toolNeon),
            ShortcutAction(id: "toolDashed", title: "Dashed", detail: "Dashed line.", scope: .drawing, name: .toolDashed),
            ShortcutAction(id: "toolEraser", title: "Eraser", detail: "Erase whole strokes by touching them.", scope: .drawing, name: .toolEraser),
            ShortcutAction(id: "toolLaser", title: "Laser pointer", detail: "A red laser dot with a trail that fades when you stop moving. Nothing is saved.", scope: .drawing, name: .toolLaser),
            ShortcutAction(id: "sizeDown", title: "Smaller brush", detail: "Make the current brush one step smaller.", scope: .drawing, name: .sizeDown),
            ShortcutAction(id: "sizeUp", title: "Larger brush", detail: "Make the current brush one step larger.", scope: .drawing, name: .sizeUp),
            ShortcutAction(id: "eyedropper", title: "Pick color from screen", detail: "Sample a color from anywhere on screen.", scope: .drawing, name: .eyedropper),
        ]
        for (index, name) in KeyboardShortcuts.Name.colorSlots.enumerated() {
            list.append(ShortcutAction(
                id: "colorSlot\(index + 1)", title: "Color slot \(index + 1)",
                detail: "Use the color saved in slot \(index + 1).", scope: .drawing, name: name))
        }
        return list
    }()

    static func action(_ id: String) -> ShortcutAction? { all.first { $0.id == id } }

    static func actions(in scope: ShortcutAction.Scope) -> [ShortcutAction] { all.filter { $0.scope == scope } }

    /// Puts every binding back to its default.
    static func resetAll() { KeyboardShortcuts.reset(all.map(\.name)) }
}
