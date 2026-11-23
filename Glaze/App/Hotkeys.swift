import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// ⌥⌘D — toggle between Pointer and Draw.
    static let toggleDraw = Self("toggleDraw", default: .init(.d, modifiers: [.option, .command]))
    /// ⌥⌘K — clear the display under the pointer (undoable).
    static let clearDisplay = Self("clearDisplay", default: .init(.k, modifiers: [.option, .command]))
    /// Esc — leave Draw. Registered only while a capture mode is active, so Esc
    /// works normally in other apps the rest of the time.
    static let exitDraw = Self("exitDraw", default: .init(.escape))
    /// ⌘Z / ⇧⌘Z — undo / redo on the display under the pointer (while drawing).
    static let undo = Self("undo", default: .init(.z, modifiers: [.command]))
    static let redo = Self("redo", default: .init(.z, modifiers: [.command, .shift]))
    /// P / E — pick the pen or the eraser (while drawing).
    static let toolPen = Self("toolPen", default: .init(.p))
    static let toolEraser = Self("toolEraser", default: .init(.e))
}

/// Global shortcuts. Uses Carbon hotkeys via KeyboardShortcuts, which need
/// neither Accessibility nor Input Monitoring permission.
@MainActor
final class Hotkeys: ModeSink {
    private let modeController: ModeController
    private weak var environment: AppEnvironment?

    // DECISION: Esc, ⌘Z, ⇧⌘Z and the plain tool letters are registered only
    // while drawing. The front app keeps keyboard focus in Draw mode (the canvas
    // never becomes key), so these have to be global hotkeys — and grabbing ⌘Z
    // or "e" outside Draw would break every other app.
    private static let captureOnly: [KeyboardShortcuts.Name] = [.exitDraw, .undo, .redo, .toolPen, .toolEraser]

    init(modeController: ModeController, environment: AppEnvironment) {
        self.modeController = modeController
        self.environment = environment
        // KeyboardShortcuts delivers on the main thread (Carbon event handler).
        on(.toggleDraw) { $0.modeController.toggle() }
        on(.clearDisplay) { $0.environment?.clearCurrentDisplay() }
        on(.exitDraw) { $0.modeController.exitToPointer() }
        on(.undo) { $0.environment?.undo() }
        on(.redo) { $0.environment?.redo() }
        on(.toolPen) { $0.modeController.select(tool: .pen) }
        on(.toolEraser) { $0.modeController.select(tool: .eraser) }
        KeyboardShortcuts.disable(Self.captureOnly)
    }

    func apply(mode: AppMode, previous: AppMode?) {
        if mode.capturesInput {
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
