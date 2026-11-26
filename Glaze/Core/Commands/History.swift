import Foundation

/// Linear undo/redo stack for one canvas.
struct History {
    // DECISION: 200 steps per display. Commands hold element snapshots, so an
    // unbounded stack would grow forever in a long session; 200 is far past what
    // anyone undoes by hand.
    static let defaultLimit = 200

    let limit: Int
    private(set) var undoStack: [any Command] = []
    private(set) var redoStack: [any Command] = []

    init(limit: Int = History.defaultLimit) {
        self.limit = max(1, limit)
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Applies `command`, records it and drops the redo stack.
    mutating func perform(_ command: any Command, on canvas: inout Canvas) {
        command.apply(to: &canvas)
        undoStack.append(command)
        if undoStack.count > limit {
            undoStack.removeFirst(undoStack.count - limit)
        }
        redoStack.removeAll()
    }

    @discardableResult
    mutating func undo(on canvas: inout Canvas) -> Bool {
        guard let command = undoStack.popLast() else { return false }
        command.revert(on: &canvas)
        redoStack.append(command)
        return true
    }

    @discardableResult
    mutating func redo(on canvas: inout Canvas) -> Bool {
        guard let command = redoStack.popLast() else { return false }
        command.apply(to: &canvas)
        undoStack.append(command)
        return true
    }
}
