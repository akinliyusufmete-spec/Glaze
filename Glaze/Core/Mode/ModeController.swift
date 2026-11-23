import Foundation
import Observation

/// The ONLY owner of mode transitions. Everything that changes
/// `ignoresMouseEvents`, the cursor or the HUD does so via a `ModeSink`
/// that this controller drives from `transition(to:)`.
@MainActor
@Observable
final class ModeController {
    private(set) var mode: AppMode = .pointer
    /// The tool used the last time we were in `.draw`, restored on toggle.
    private(set) var lastTool: ToolID = .pen

    @ObservationIgnored private var sinks: [WeakSink] = []

    init() {}

    // MARK: Sinks

    /// Registers a sink and immediately brings it up to date (with `previous: nil`).
    func attach(_ sink: ModeSink) {
        sinks.removeAll { $0.value == nil || $0.value === sink }
        sinks.append(WeakSink(value: sink))
        sink.apply(mode: mode, previous: nil)
    }

    /// Re-applies the current mode to every sink without announcing a change.
    /// Used when windows are created or displays are rearranged.
    func resync() {
        for sink in liveSinks() { sink.apply(mode: mode, previous: nil) }
    }

    // MARK: Transitions

    /// The single choke point for mode changes.
    func transition(to newMode: AppMode) {
        let target = Self.normalize(newMode)
        guard target != mode else { return }
        let previous = mode
        mode = target
        if let tool = target.tool { lastTool = tool }
        for sink in liveSinks() { sink.apply(mode: target, previous: previous) }
    }

    /// ⌥⌘D. Pointer → Draw (last tool); Draw → Pointer.
    // DECISION: toggling during a momentary draw latches into full Draw mode
    // instead of leaving early: the user pressed "draw" while drawing, so the
    // least surprising result is to keep drawing after the hold key is released.
    func toggle() {
        switch mode {
        case .pointer, .momentaryDraw: transition(to: .draw(tool: lastTool))
        case .draw: transition(to: .pointer)
        }
    }

    /// Esc, or the menu item.
    func exitToPointer() { transition(to: .pointer) }

    /// Picks a tool and enters Draw mode with it.
    func select(tool: ToolID) { transition(to: .draw(tool: tool)) }

    /// Hold-to-draw key went down. Only meaningful from Pointer.
    func beginMomentaryDraw() {
        guard mode == .pointer else { return }
        transition(to: .momentaryDraw(returnTo: .pointer))
    }

    /// Hold-to-draw key came up.
    func endMomentaryDraw() {
        guard case let .momentaryDraw(returnTo) = mode else { return }
        transition(to: returnTo)
    }

    // MARK: Helpers

    /// `.momentaryDraw` never nests: its `returnTo` is always a non-momentary mode.
    static func normalize(_ mode: AppMode) -> AppMode {
        guard case var .momentaryDraw(returnTo) = mode else { return mode }
        while case let .momentaryDraw(inner) = returnTo { returnTo = inner }
        return .momentaryDraw(returnTo: returnTo)
    }

    private func liveSinks() -> [ModeSink] {
        sinks.removeAll { $0.value == nil }
        return sinks.compactMap(\.value)
    }

    private struct WeakSink {
        weak var value: ModeSink?
    }
}
