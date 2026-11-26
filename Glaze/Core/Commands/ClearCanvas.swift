import Foundation

/// Removes everything from a canvas. Undo puts it all back (F10).
struct ClearCanvas: Command {
    let snapshot: [any Element]

    init(canvas: Canvas) {
        snapshot = canvas.elements
    }

    func apply(to canvas: inout Canvas) {
        canvas.removeAll()
    }

    func revert(on canvas: inout Canvas) {
        canvas.replaceAll(with: snapshot)
    }
}
