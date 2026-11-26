import Foundation
import Observation

/// User preferences, persisted in UserDefaults.
///
/// DECISION: an @Observable class rather than @AppStorage, because
/// non-view objects (the HUD controller, the dock) need to read these values, and
/// @AppStorage only works inside SwiftUI views.
@MainActor
@Observable
final class Preferences {
    private enum Key {
        static let showModeHUD = "showModeHUD"
        static let showToolbar = "showToolbar"
        static let automaticUpdateChecks = "automaticUpdateChecks"
        static let drawOverFullScreenGames = "drawOverFullScreenGames"
        static let toolbarPlacement = "toolbarPlacement"
        static let toolbarReveal = "toolbarReveal"
        static let autoHideDelay = "autoHideDelay"
        static let animationStyle = "animationStyle"
        static let animationDuration = "animationDuration"
        static let hintsEnabled = "hintsEnabled"
        static let hintDelay = "hintDelay"
    }

    static let autoHideRange: ClosedRange<Double> = 0.5...6
    static let animationDurationRange: ClosedRange<Double> = 0.05...0.8
    static let hintDelayRange: ClosedRange<Double> = 0...1.5

    @ObservationIgnored private let defaults: UserDefaults
    /// Called after any preference changes, so windows can re-apply layout, levels and timing.
    @ObservationIgnored var onChange: (() -> Void)?

    var showModeHUD: Bool {
        didSet { save(showModeHUD, Key.showModeHUD) }
    }

    /// Whether the toolbar appears in Draw mode when it is "always visible".
    var showToolbar: Bool {
        didSet { save(showToolbar, Key.showToolbar) }
    }

    /// Whether Glaze looks for a newer GitHub release at launch (at most once a day).
    var automaticUpdateChecks: Bool {
        didSet { save(automaticUpdateChecks, Key.automaticUpdateChecks) }
    }

    /// Experimental: raise Glaze's windows above exclusive-full-screen games (see `WindowLevels`).
    var drawOverFullScreenGames: Bool {
        didSet { save(drawOverFullScreenGames, Key.drawOverFullScreenGames) }
    }

    var toolbarPlacement: ToolbarPlacement {
        didSet { save(toolbarPlacement.rawValue, Key.toolbarPlacement) }
    }

    var toolbarReveal: ToolbarReveal {
        didSet { save(toolbarReveal.rawValue, Key.toolbarReveal) }
    }

    /// Seconds the pointer may stay away from the toolbar before it tucks back behind its edge handle.
    var autoHideDelay: Double {
        didSet { save(autoHideDelay, Key.autoHideDelay) }
    }

    var animationStyle: AnimationStyle {
        didSet { save(animationStyle.rawValue, Key.animationStyle) }
    }

    /// Seconds a show/hide animation takes.
    var animationDuration: Double {
        didSet { save(animationDuration, Key.animationDuration) }
    }

    /// Whether hovering a button shows its name and keyboard shortcut.
    var hintsEnabled: Bool {
        didSet { save(hintsEnabled, Key.hintsEnabled) }
    }

    /// Seconds the pointer rests on a button before its hint appears.
    var hintDelay: Double {
        didSet { save(hintDelay, Key.hintDelay) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.showModeHUD: true, Key.showToolbar: true, Key.automaticUpdateChecks: true,
            Key.drawOverFullScreenGames: false,
            Key.toolbarPlacement: ToolbarPlacement.top.rawValue,
            Key.toolbarReveal: ToolbarReveal.always.rawValue,
            Key.autoHideDelay: 2.0,
            Key.animationStyle: AnimationStyle.slideFade.rawValue,
            Key.animationDuration: 0.22,
            Key.hintsEnabled: true, Key.hintDelay: 0.45,
        ])
        showModeHUD = defaults.bool(forKey: Key.showModeHUD)
        showToolbar = defaults.bool(forKey: Key.showToolbar)
        automaticUpdateChecks = defaults.bool(forKey: Key.automaticUpdateChecks)
        drawOverFullScreenGames = defaults.bool(forKey: Key.drawOverFullScreenGames)
        toolbarPlacement = defaults.string(forKey: Key.toolbarPlacement).flatMap(ToolbarPlacement.init) ?? .top
        toolbarReveal = defaults.string(forKey: Key.toolbarReveal).flatMap(ToolbarReveal.init) ?? .always
        autoHideDelay = Self.autoHideRange.clamp(defaults.double(forKey: Key.autoHideDelay))
        animationStyle = defaults.string(forKey: Key.animationStyle).flatMap(AnimationStyle.init) ?? .slideFade
        animationDuration = Self.animationDurationRange.clamp(defaults.double(forKey: Key.animationDuration))
        hintsEnabled = defaults.bool(forKey: Key.hintsEnabled)
        hintDelay = Self.hintDelayRange.clamp(defaults.double(forKey: Key.hintDelay))
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
        onChange?()
    }
}

extension ClosedRange where Bound == Double {
    func clamp(_ value: Double) -> Double { Swift.min(Swift.max(value, lowerBound), upperBound) }
}
