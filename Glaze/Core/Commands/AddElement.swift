import Foundation

/// Adds one element on top of the canvas.
struct AddElement: Command {
    let element: any Element

    func apply(to canvas: inout Canvas) {
        canvas.append(element)
    }

    func revert(on canvas: inout Canvas) {
        canvas.remove(ids: [element.id])
    }
}
