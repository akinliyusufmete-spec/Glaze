import AppKit
import Observation

/// Composition root. The only shared object in the app; everything else is
/// created here and handed its dependencies explicitly.
@MainActor
@Observable
final class AppEnvironment {
    let preferences = Preferences()
    let modeController = ModeController()

    @ObservationIgnored private(set) var overlays: OverlayManager?
    @ObservationIgnored private var hud: HUDController?
    @ObservationIgnored private var hotkeys: Hotkeys?
    @ObservationIgnored private var focusRestorer: FocusRestorer?
    @ObservationIgnored private var launchObserver: NSObjectProtocol?
    #if DEBUG
    @ObservationIgnored private var debugCommands: DebugCommands?
    #endif

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        // DECISION: under XCTest the host app stays inert — no overlay windows or
        // global hotkeys — so unit tests don't cover the screen or grab ⌥⌘D.
        guard !Self.isRunningTests else { return }
        launchObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.start() }
        }
    }

    private func start() {
        guard overlays == nil else { return }
        let overlays = OverlayManager()
        overlays.onEscape = { [weak self] in self?.modeController.exitToPointer() }
        let focusRestorer = FocusRestorer()
        let hud = HUDController(preferences: preferences)
        let hotkeys = Hotkeys(modeController: modeController)

        // Order matters on exit: overlays go click-through before focus is handed back.
        modeController.attach(overlays)
        modeController.attach(focusRestorer)
        modeController.attach(hotkeys)
        modeController.attach(hud)

        self.overlays = overlays
        self.focusRestorer = focusRestorer
        self.hud = hud
        self.hotkeys = hotkeys
        #if DEBUG
        debugCommands = DebugCommands(environment: self)
        #endif
    }

    func clearDrawings() {
        overlays?.clearAll()
    }
}
