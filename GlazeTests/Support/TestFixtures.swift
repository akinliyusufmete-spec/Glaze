import CoreGraphics
import Foundation
@testable import Glaze

/// Small builders shared by the Phase 2 tests.
enum Fixtures {
    static let red = CGColor(red: 1, green: 0, blue: 0, alpha: 1)

    /// A straight horizontal stroke from (x0, y) to (x1, y).
    static func line(x0: CGFloat = 0, x1: CGFloat = 100, y: CGFloat = 0, width: CGFloat = 4) -> StrokeElement {
        StrokeElement(points: [CGPoint(x: x0, y: y), CGPoint(x: x1, y: y)], color: red, width: width)
    }

    static func ids(_ canvas: Canvas) -> [UUID] {
        canvas.elements.map(\.id)
    }
}

/// A `ToolContext` with no view: applies commands through a real `History`
/// and records what the tool asked the live layer to show.
@MainActor
final class FakeToolContext: ToolContext {
    var canvas = Canvas()
    var history = History()
    private(set) var performed: [any Command] = []
    private(set) var liveCalls: [(element: (any Element)?, dirty: CGRect?)] = []
    private(set) var pendingRemoval: Set<UUID> = []

    var lastLive: (any Element)? { liveCalls.last?.element ?? nil }

    func perform(_ command: any Command) {
        performed.append(command)
        history.perform(command, on: &canvas)
    }

    func showLive(_ element: (any Element)?, dirty: CGRect?) {
        liveCalls.append((element, dirty))
    }

    func setPendingRemoval(_ ids: Set<UUID>) {
        pendingRemoval = ids
    }

    func undo() { history.undo(on: &canvas) }
    func redo() { history.redo(on: &canvas) }
}
