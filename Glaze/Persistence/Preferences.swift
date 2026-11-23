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
    }

    @ObservationIgnored private let defaults: UserDefaults

    var showModeHUD: Bool {
        didSet { defaults.set(showModeHUD, forKey: Key.showModeHUD) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.showModeHUD: true])
        showModeHUD = defaults.bool(forKey: Key.showModeHUD)
    }
}
