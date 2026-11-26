import Foundation

/// Removes a set of elements, restoring them at their original z-order on undo.
struct RemoveElements: Command {
    /// Ascending by index, as they were in the canvas when the command was made.
    let removed: [(index: Int, element: any Element)]

    /// Snapshots the elements of `canvas` whose ids are in `ids`. Unknown ids are ignored.
    init(ids: Set<UUID>, in canvas: Canvas) {
        removed = canvas.elements.enumerated()
            .filter { ids.contains($0.element.id) }
            .map { (index: $0.offset, element: $0.element) }
    }

    var isEmpty: Bool { removed.isEmpty }

    func apply(to canvas: inout Canvas) {
        canvas.remove(ids: Set(removed.map(\.element.id)))
    }

    func revert(on canvas: inout Canvas) {
        // Ascending order: each original index is valid once everything below it is back.
        for item in removed {
            canvas.insert(item.element, at: item.index)
        }
    }
}
