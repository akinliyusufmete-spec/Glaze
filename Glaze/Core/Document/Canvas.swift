import CoreGraphics
import Foundation

/// The elements on one display, bottom to top.
///
/// DECISION: the mutators below are internal (not private) because `Command`s
/// live in their own files, but by convention only `Command.apply/revert` call
/// them. Everything else changes a canvas through `CanvasStore.perform`, so every
/// change is undoable.
struct Canvas {
    private(set) var elements: [any Element] = []
    var selection: Set<UUID> = []
    /// Bumped on every mutation; renderers use it to skip redundant work.
    private(set) var revision = 0

    var isEmpty: Bool { elements.isEmpty }

    func index(of id: UUID) -> Int? {
        elements.firstIndex { $0.id == id }
    }

    func element(withID id: UUID) -> (any Element)? {
        index(of: id).map { elements[$0] }
    }

    mutating func append(_ element: any Element) {
        elements.append(element)
        revision += 1
    }

    /// Inserts at `index`, clamped into range.
    mutating func insert(_ element: any Element, at index: Int) {
        elements.insert(element, at: max(0, min(index, elements.count)))
        revision += 1
    }

    /// Removes every element whose id is in `ids` and returns them with their
    /// original indices, ascending.
    @discardableResult
    mutating func remove(ids: Set<UUID>) -> [(index: Int, element: any Element)] {
        var removed: [(index: Int, element: any Element)] = []
        for (index, element) in elements.enumerated() where ids.contains(element.id) {
            removed.append((index, element))
        }
        guard !removed.isEmpty else { return [] }
        elements.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
        revision += 1
        return removed
    }

    @discardableResult
    mutating func removeAll() -> [any Element] {
        let old = elements
        elements.removeAll()
        selection.removeAll()
        revision += 1
        return old
    }

    mutating func replaceAll(with elements: [any Element]) {
        self.elements = elements
        selection.removeAll()
        revision += 1
    }
}
