import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// ⌥⌘D — toggle between Pointer and Draw.
    static let toggleDraw = Self("toggleDraw", default: .init(.d, modifiers: [.option, .command]))
    /// Esc — leave Draw. Registered only while a capture mode is active, so Esc
    /// works normally in other apps the rest of the time.
    static let exitDraw = Self("exitDraw", default: .init(.escape))
}

/// Global shortcuts. Uses Carbon hotkeys via KeyboardShortcuts, which need
/// neither Accessibility nor Input Monitoring permission.
@MainActor
final class Hotkeys: ModeSink {
    private let modeController: ModeController

    init(modeController: ModeController) {
        self.modeController = modeController
        // KeyboardShortcuts delivers on the main thread (Carbon event handler).
        KeyboardShortcuts.onKeyDown(for: .toggleDraw) { [weak self] in
            MainActor.assumeIsolated { self?.modeController.toggle() }
        }
        KeyboardShortcuts.onKeyDown(for: .exitDraw) { [weak self] in
            MainActor.assumeIsolated { self?.modeController.exitToPointer() }
        }
        KeyboardShortcuts.disable(.exitDraw)
    }

    func apply(mode: AppMode, previous: AppMode?) {
        if mode.capturesInput {
            KeyboardShortcuts.enable(.exitDraw)
        } else {
            KeyboardShortcuts.disable(.exitDraw)
        }
    }
}
