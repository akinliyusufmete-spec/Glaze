import CoreGraphics
import Foundation

/// Every display's canvas and history. The single place canvases change.
///
/// DECISION: canvases are keyed by display ID and outlive their overlay window,
/// so unplugging a display and plugging it back in brings its drawing back.
@MainActor
final class CanvasStore {
    typealias DisplayID = CGDirectDisplayID

    private var canvases: [DisplayID: Canvas] = [:]
    private var histories: [DisplayID: History] = [:]

    /// Called after any change to a display's canvas.
    var onChange: ((DisplayID) -> Void)?

    func canvas(for display: DisplayID) -> Canvas {
        canvases[display] ?? Canvas()
    }

    var displayIDs: [DisplayID] { canvases.keys.sorted() }

    func perform(_ command: any Command, on display: DisplayID) {
        // Mutate in place so the element array isn't copied on every stroke.
        histories[display, default: History()].perform(command, on: &canvases[display, default: Canvas()])
        onChange?(display)
    }

    /// Replaces a canvas wholesale with `elements` and a fresh, empty history. For loading saved
    /// work: the loaded elements are not undoable steps.
    func load(_ elements: [any Element], on display: DisplayID) {
        var canvas = Canvas()
        canvas.replaceAll(with: elements)
        canvases[display] = canvas
        histories[display] = History()
        onChange?(display)
    }

    @discardableResult
    func undo(on display: DisplayID) -> Bool {
        guard histories[display]?.canUndo == true else { return false }
        histories[display, default: History()].undo(on: &canvases[display, default: Canvas()])
        onChange?(display)
        return true
    }

    @discardableResult
    func redo(on display: DisplayID) -> Bool {
        guard histories[display]?.canRedo == true else { return false }
        histories[display, default: History()].redo(on: &canvases[display, default: Canvas()])
        onChange?(display)
        return true
    }

    func canUndo(on display: DisplayID) -> Bool { histories[display]?.canUndo ?? false }
    func canRedo(on display: DisplayID) -> Bool { histories[display]?.canRedo ?? false }
    func undoCount(on display: DisplayID) -> Int { histories[display]?.undoStack.count ?? 0 }
    func redoCount(on display: DisplayID) -> Int { histories[display]?.redoStack.count ?? 0 }
}
