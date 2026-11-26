import Foundation
import Observation

/// User preferences, persisted in UserDefaults.
///
/// DECISION: an @Observable class rather than @AppStorage, because
/// non-view objects (the HUD controller) need to read these values, and
/// @AppStorage only works inside SwiftUI views.
@MainActor
@Observable
final class Preferences {
    private enum Key {
        static let showModeHUD = "showModeHUD"
        static let showToolbar = "showToolbar"
        static let automaticUpdateChecks = "automaticUpdateChecks"
        static let drawOverFullScreenGames = "drawOverFullScreenGames"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var showModeHUD: Bool {
        didSet { defaults.set(showModeHUD, forKey: Key.showModeHUD) }
    }

    /// Whether the toolbar appears in Draw mode.
    var showToolbar: Bool {
        didSet { defaults.set(showToolbar, forKey: Key.showToolbar) }
    }

    /// Whether Glaze looks for a newer GitHub release at launch (at most once a day).
    var automaticUpdateChecks: Bool {
        didSet { defaults.set(automaticUpdateChecks, forKey: Key.automaticUpdateChecks) }
    }

    /// Experimental: raise Glaze's windows above exclusive-full-screen games (see `WindowLevels`).
    var drawOverFullScreenGames: Bool {
        didSet { defaults.set(drawOverFullScreenGames, forKey: Key.drawOverFullScreenGames) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.showModeHUD: true, Key.showToolbar: true, Key.automaticUpdateChecks: true, Key.drawOverFullScreenGames: false])
        showModeHUD = defaults.bool(forKey: Key.showModeHUD)
        showToolbar = defaults.bool(forKey: Key.showToolbar)
        automaticUpdateChecks = defaults.bool(forKey: Key.automaticUpdateChecks)
        drawOverFullScreenGames = defaults.bool(forKey: Key.drawOverFullScreenGames)
    }
}
