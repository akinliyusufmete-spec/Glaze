import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// ⌥⌘D — toggle between Pointer and Draw.
    static let toggleDraw = Self("toggleDraw", default: .init(.d, modifiers: [.option, .command]))
    /// ⌥⌘N — open or close the notepad. Global, and independent of Draw mode.
    static let toggleNotepad = Self("toggleNotepad", default: .init(.n, modifiers: [.option, .command]))
    /// ⌥⌘K — clear the display under the pointer (undoable).
    static let clearDisplay = Self("clearDisplay", default: .init(.k, modifiers: [.option, .command]))
    /// Esc — leave Draw. Registered only while a capture mode is active, so Esc
    /// works normally in other apps the rest of the time.
    static let exitDraw = Self("exitDraw", default: .init(.escape))
    /// ⌘Z / ⇧⌘Z — undo / redo on the display under the pointer (while drawing).
    static let undo = Self("undo", default: .init(.z, modifiers: [.command]))
    static let redo = Self("redo", default: .init(.z, modifiers: [.command, .shift]))
    /// P / M / H / E — pick the pen, marker, highlighter or eraser (while drawing).
    static let toolPen = Self("toolPen", default: .init(.p))
    static let toolMarker = Self("toolMarker", default: .init(.m))
    static let toolHighlighter = Self("toolHighlighter", default: .init(.h))
    static let toolEraser = Self("toolEraser", default: .init(.e))
    /// [ / ] — brush size down / up (while drawing).
    static let sizeDown = Self("sizeDown", default: .init(.leftBracket))
    static let sizeUp = Self("sizeUp", default: .init(.rightBracket))
    /// C — eyedropper (while drawing).
    static let eyedropper = Self("eyedropper", default: .init(.c))

    /// 1…9 — color slots (while drawing).
    static let colorSlots: [KeyboardShortcuts.Name] = [
        Key.one, .two, .three, .four, .five, .six, .seven, .eight, .nine,
    ].enumerated().map { index, key in
        Self("colorSlot\(index + 1)", default: .init(key))
    }

    private typealias Key = KeyboardShortcuts.Key
}

/// Global shortcuts. Uses Carbon hotkeys via KeyboardShortcuts, which need
/// neither Accessibility nor Input Monitoring permission.
@MainActor
final class Hotkeys: ModeSink {
    private let modeController: ModeController
    private weak var environment: AppEnvironment?

    // DECISION: Esc, ⌘Z, ⇧⌘Z and the plain keys are registered only while drawing.
    // The front app keeps keyboard focus in Draw mode (the canvas never becomes key),
    // so these have to be global hotkeys — and grabbing ⌘Z or "e" outside Draw would
    // break every other app.
    private static let captureOnly: [KeyboardShortcuts.Name] =
        [.exitDraw, .undo, .redo, .toolPen, .toolMarker, .toolHighlighter, .toolEraser,
         .sizeDown, .sizeUp, .eyedropper] + KeyboardShortcuts.Name.colorSlots

    private var capturing = false
    /// DECISION: while a Glaze panel has the keyboard (the color panel's hex field, the notepad's
    /// text), the plain keys must type text ("E" and "1" are valid hex digits), so the capture-only
    /// set is switched off. Several panels can ask, so each is tracked by name.
    private var suspendedBy: Set<String> = []

    init(modeController: ModeController, environment: AppEnvironment) {
        self.modeController = modeController
        self.environment = environment
        // KeyboardShortcuts delivers on the main thread (Carbon event handler).
        on(.toggleDraw) { $0.modeController.toggle() }
        on(.toggleNotepad) { $0.environment?.toggleNotepad() }
        on(.clearDisplay) { $0.environment?.clearCurrentDisplay() }
        on(.exitDraw) { $0.modeController.exitToPointer() }
        on(.undo) { $0.environment?.undo() }
        on(.redo) { $0.environment?.redo() }
        on(.toolPen) { $0.modeController.select(tool: .pen) }
        on(.toolMarker) { $0.modeController.select(tool: .marker) }
        on(.toolHighlighter) { $0.modeController.select(tool: .highlighter) }
        on(.toolEraser) { $0.modeController.select(tool: .eraser) }
        on(.sizeDown) { $0.environment?.stepBrushSize(up: false) }
        on(.sizeUp) { $0.environment?.stepBrushSize(up: true) }
        on(.eyedropper) { $0.environment?.pickColorFromScreen() }
        for (index, name) in KeyboardShortcuts.Name.colorSlots.enumerated() {
            on(name) { $0.environment?.selectColorSlot(index) }
        }
        KeyboardShortcuts.disable(Self.captureOnly)
    }

    func apply(mode: AppMode, previous: AppMode?) {
        capturing = mode.capturesInput
        refresh()
    }

    /// Called by a panel when it gains or loses the keyboard.
    func setSuspended(_ suspended: Bool, by owner: String) {
        if suspended { suspendedBy.insert(owner) } else { suspendedBy.remove(owner) }
        refresh()
    }

    private func refresh() {
        if capturing, suspendedBy.isEmpty {
            KeyboardShortcuts.enable(Self.captureOnly)
        } else {
            KeyboardShortcuts.disable(Self.captureOnly)
        }
    }

    private func on(_ name: KeyboardShortcuts.Name, _ action: @escaping @MainActor (Hotkeys) -> Void) {
        KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                action(self)
            }
        }
    }
}
