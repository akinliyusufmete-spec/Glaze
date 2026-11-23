import AppKit
import Observation

/// Composition root. The only shared object in the app; everything else is
/// created here and handed its dependencies explicitly.
@MainActor
@Observable
final class AppEnvironment {
    let preferences = Preferences()
    let modeController = ModeController()
    @ObservationIgnored let canvasStore = CanvasStore()
    @ObservationIgnored let toolRegistry = ToolRegistry()

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
        let overlays = OverlayManager(store: canvasStore, registry: toolRegistry)
        overlays.onEscape = { [weak self] in self?.modeController.exitToPointer() }
        let focusRestorer = FocusRestorer()
        let hud = HUDController(preferences: preferences)
        let hotkeys = Hotkeys(modeController: modeController, environment: self)

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

    // DECISION: undo, redo and clear act on the display under the pointer —
    // that's the drawing the user is looking at, and F10 makes history per display.
    func undo() {
        guard let id = overlays?.displayUnderMouse() else { return }
        canvasStore.undo(on: id)
    }

    func redo() {
        guard let id = overlays?.displayUnderMouse() else { return }
        canvasStore.redo(on: id)
    }

    /// Clears the display under the pointer as one undoable step.
    func clearCurrentDisplay() {
        guard let id = overlays?.displayUnderMouse() else { return }
        clear(id)
    }

    /// Clears every display; each clear is its own undo step on its display.
    func clearAllDisplays() {
        canvasStore.displayIDs.forEach(clear)
    }

    private func clear(_ id: CanvasStore.DisplayID) {
        let canvas = canvasStore.canvas(for: id)
        guard !canvas.isEmpty else { return }
        canvasStore.perform(ClearCanvas(canvas: canvas), on: id)
    }
}
