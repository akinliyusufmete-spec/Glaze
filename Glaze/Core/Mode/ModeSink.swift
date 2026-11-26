import Foundation

/// Anything that reacts to mode changes (overlay windows, cursor, HUD).
/// Sinks never decide the mode; they only apply what `ModeController` tells them.
@MainActor
protocol ModeSink: AnyObject {
    /// - Parameter previous: the mode before this change, or `nil` when the
    ///   controller is re-applying the current mode (first attach, display change).
    ///   Sinks with user-visible feedback (the HUD) should stay quiet when it's `nil`.
    func apply(mode: AppMode, previous: AppMode?)
}
