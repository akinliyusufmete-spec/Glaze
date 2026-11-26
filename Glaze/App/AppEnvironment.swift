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
    @ObservationIgnored let toolSettings: ToolSettings
    @ObservationIgnored let toolRegistry: ToolRegistry
    let updateChecker = UpdateChecker(currentVersion: UpdateChecker.bundleVersion())

    @ObservationIgnored private(set) var overlays: OverlayManager?
    @ObservationIgnored private var hud: HUDController?
    @ObservationIgnored private var hotkeys: Hotkeys?
    @ObservationIgnored private var toolbar: ToolbarController?
    @ObservationIgnored private var colorPanel: ColorPanelController?
    @ObservationIgnored private var notepad: NotepadController?
    /// Which window the color panel is currently attached to (it follows that window).
    @ObservationIgnored private var colorPanelAnchor: ColorPanelAnchor = .toolbar
    @ObservationIgnored private var toolbarSink: ToolbarModeSink?
    @ObservationIgnored private var focusRestorer: FocusRestorer?
    @ObservationIgnored private var launchObserver: NSObjectProtocol?
    #if DEBUG
    @ObservationIgnored private var debugCommands: DebugCommands?
    #endif

    private enum ColorPanelAnchor { case toolbar, notepad }

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        let settings = ToolSettings()
        toolSettings = settings
        toolRegistry = ToolRegistry(settings: settings)
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


        let toolbarState = ToolbarState()
        let colorPanel = ColorPanelController(model: ColorPanelModel(settings: toolSettings))
        let toolbar = ToolbarController(
            entries: ToolbarEntry.defaults,
            actions: makeToolbarActions(),
            state: toolbarState,
            settings: toolSettings
        )
        let toolbarSink = ToolbarModeSink(toolbar: toolbar, colorPanel: colorPanel,
                                          state: toolbarState, preferences: preferences)
        colorPanel.onVisibilityChange = { toolbarState.isColorPanelVisible = $0 }
        colorPanel.onKeyStatusChange = { [weak hotkeys] in hotkeys?.setSuspended($0, by: "colorPanel") }
        toolbar.onMove = { [weak self] in
            guard let self, self.colorPanelAnchor == .toolbar,
                  let toolbar = self.toolbar, let panel = self.colorPanel, panel.isVisible else { return }
            panel.place(anchor: toolbar.frame, preferred: .below)
        }

        let notepad = NotepadController(
            model: NotepadModel(storage: NotebookStorage(url: NotebookStorage.defaultURL), registry: toolRegistry),
            settings: toolSettings
        )
        notepad.onKeyStatusChange = { [weak hotkeys] in hotkeys?.setSuspended($0, by: "notepad") }
        notepad.onColorRequest = { [weak self] in self?.toggleColorPanel(from: .notepad) }
        notepad.onMove = { [weak self] in
            guard let self, self.colorPanelAnchor == .notepad,
                  let notepad = self.notepad, let panel = self.colorPanel, panel.isVisible else { return }
            panel.place(anchor: notepad.frame, preferred: .right)
        }
        notepad.onVisibilityChange = { [weak self] visible in
            // The color panel hangs off the notepad while it is open; closing the pad closes it.
            if !visible, self?.colorPanelAnchor == .notepad { self?.colorPanel?.hide() }
        }

        // Order matters on exit: overlays go click-through before focus is handed back.
        modeController.attach(overlays)
        modeController.attach(focusRestorer)
        modeController.attach(hotkeys)
        modeController.attach(hud)
        modeController.attach(toolbarSink)

        self.overlays = overlays
        self.focusRestorer = focusRestorer
        self.hud = hud
        self.hotkeys = hotkeys
        self.toolbar = toolbar
        self.colorPanel = colorPanel
        self.notepad = notepad
        self.toolbarSink = toolbarSink
        applyWindowLevels()
        #if DEBUG
        debugCommands = DebugCommands(environment: self)
        #endif
        if preferences.automaticUpdateChecks {
            Task { await updateChecker.checkIfDue() }
        }
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

    // MARK: Brush size, color, toolbar

    var isToolbarVisible: Bool { toolbar?.isVisible ?? false }
    var isColorPanelVisible: Bool { colorPanel?.isVisible ?? false }

    /// `[` / `]`: moves the active brush one rung along `SizeStepper.ladder`.
    // DECISION: sizes are per brush (a wide highlighter shouldn't make the pen wide), and the
    // eraser has no size control yet — it keeps its fixed radius.
    func stepBrushSize(up: Bool) {
        let tool = modeController.mode.tool ?? modeController.lastTool
        guard let preset = BrushPresets.preset(for: tool) else { return }
        toolSettings.stepWidth(for: tool, presetWidth: preset.baseWidth, up: up)
    }

    /// Keys 1–9 (0-based index here).
    func selectColorSlot(_ index: Int) {
        toolSettings.selectSlot(index)
        colorPanel?.model.syncFromSettings()
    }

    /// Eyedropper (C, the toolbar button's panel, or the menu).
    func pickColorFromScreen() {
        colorPanel?.pickFromScreen()
    }

    func toggleColorPanel() { toggleColorPanel(from: .toolbar) }

    private func toggleColorPanel(from anchor: ColorPanelAnchor) {
        guard let colorPanel else { return }
        // Pressing the same button again closes the panel; the other window's button moves it.
        if colorPanel.isVisible, colorPanelAnchor == anchor { return colorPanel.hide() }
        colorPanelAnchor = anchor
        switch anchor {
        case .toolbar:
            guard let toolbar else { return }
            // The panel hangs off the toolbar, so make sure the toolbar is up first.
            if !toolbar.isVisible { toolbar.show() }
            colorPanel.show(anchor: toolbar.frame, preferred: .below)
        case .notepad:
            guard let notepad else { return }
            colorPanel.show(anchor: notepad.frame, preferred: .right)
        }
    }

    /// ⌥⌘N, the toolbar button or the menu. Works in Pointer mode: the notepad never needs Draw mode.
    func toggleNotepad() { notepad?.toggle() }

    var isNotepadVisible: Bool { notepad?.isVisible ?? false }

    /// Experimental toggle: raise every Glaze window above exclusive-full-screen games.
    func setDrawOverFullScreenGames(_ enabled: Bool) {
        preferences.drawOverFullScreenGames = enabled
        applyWindowLevels()
    }

    private func applyWindowLevels() {
        let levels = WindowLevels(coverFullScreenGames: preferences.drawOverFullScreenGames)
        overlays?.setLevel(levels.overlay)
        hud?.setLevel(levels.panel)
        toolbar?.setLevel(levels.panel)
        colorPanel?.setLevel(levels.panel)
        notepad?.setLevel(levels.panel)
    }

    func toggleToolbar() {
        preferences.showToolbar.toggle()
        toolbarSink?.refresh(mode: modeController.mode)
    }

    private func makeToolbarActions() -> ToolbarActions {
        ToolbarActions(
            selectTool: { [weak self] id in
                guard let tool = ToolID(rawValue: id) else { return }
                self?.modeController.select(tool: tool)
            },
            perform: { [weak self] id in self?.performToolbarAction(id) },
            toggleColorPanel: { [weak self] in self?.toggleColorPanel() }
        )
    }

    private func performToolbarAction(_ id: String) {
        switch id {
        case ToolbarActionID.undo: undo()
        case ToolbarActionID.redo: redo()
        case ToolbarActionID.clear: clearCurrentDisplay()
        case ToolbarActionID.sizeDown: stepBrushSize(up: false)
        case ToolbarActionID.sizeUp: stepBrushSize(up: true)
        case ToolbarActionID.notepad: toggleNotepad()
        default: break
        }
    }
}
