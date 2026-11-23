import Foundation

/// A reversible change to a canvas. `revert` must exactly undo `apply`.
///
/// DECISION: commands are immutable snapshots — they capture everything they
/// need at creation time (e.g. the elements a clear removed), so applying and
/// reverting them any number of times is deterministic. TransformElement and
/// friends arrive with the selection tool.
protocol Command {
    func apply(to canvas: inout Canvas)
    func revert(on canvas: inout Canvas)
}
