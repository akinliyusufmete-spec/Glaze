import AppKit
import QuartzCore

/// One display's drawing surface. Turns mouse/tablet events into tool
/// gestures and shows the display's canvas as two layers: the committed bitmap
/// (everything finished) and the live layer (the stroke in progress).
///
/// The view never changes the canvas itself; tools do, through `perform`,
/// which goes to `CanvasStore` as a `Command` so every change can be undone.
@MainActor
final class CanvasView: NSView, ToolContext {
    let displayID: CanvasStore.DisplayID

    var isCapturing = false {
        didSet {
            guard isCapturing != oldValue else { return }
            if !isCapturing {
                endGesture()
                tool.deactivate(context: self)
            }
            window?.invalidateCursorRects(for: self)
        }
    }

    /// Called when Esc is pressed while capturing.
    var onEscape: (() -> Void)?

    /// The active tool. Changing it mid-drag finishes the current gesture first.
    var toolID: ToolID = .pen {
        didSet {
            guard toolID != oldValue else { return }
            // DECISION: switching tools mid-drag commits what was drawn so far
            // rather than throwing it away; it's one undo step either way.
            endGesture()
            tool.deactivate(context: self)
            tool = registry.makeTool(toolID)
            applyCursor()
        }
    }

    private let store: CanvasStore
    private let registry: ToolRegistry
    private(set) var tool: any Tool
    // Internal rather than private so CanvasView+Debug can drive them.
    let committed = CommittedLayer()
    let live = LiveLayer()

    var committedDirty = true
    private(set) var pendingRemoval: Set<UUID> = []
    private var gestureActive = false
    private var lastPoint: InputPoint?

    init(frame frameRect: NSRect, displayID: CanvasStore.DisplayID, store: CanvasStore, registry: ToolRegistry) {
        self.displayID = displayID
        self.store = store
        self.registry = registry
        self.tool = registry.makeTool(.pen)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .clear
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.addSublayer(committed.layer)
        layer?.addSublayer(live.layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// When true and not capturing, the view is invisible to the mouse so views beneath it
    /// (the notepad's text) get the clicks. The full-screen overlay leaves this off: it relies on
    /// its window's `ignoresMouseEvents` instead.
    var passesThroughWhenIdle = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        passesThroughWhenIdle && !isCapturing ? nil : super.hitTest(point)
    }

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    // DECISION: the canvas never asks the panel to become key. Mouse input
    // reaches a non-key panel anyway (acceptsFirstMouse), and Esc arrives
    // through a global hotkey registered only while drawing (see Hotkeys), so the
    // front app keeps keyboard focus the whole time. Later tools that need typing
    // (text) can flip this on; FocusRestorer already hands key status back.
    override var needsPanelToBecomeKey: Bool { false }

    /// Called by the store whenever this display's canvas changes.
    func canvasDidChange() {
        committedDirty = true
        needsDisplay = true
    }

    // MARK: Layers

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        guard committedDirty else { return }
        committedDirty = false
        committed.render(canvas, hiding: pendingRemoval)
    }

    override func layout() {
        super.layout()
        syncLayerGeometry()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        syncLayerGeometry()
    }

    private func syncLayerGeometry() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        committed.layer.frame = bounds
        live.layer.frame = bounds
        live.layer.contentsScale = scale
        CATransaction.commit()
        committed.resize(to: bounds.size, scale: scale)
        committedDirty = true
        needsDisplay = true
    }

    // MARK: ToolContext

    var canvas: Canvas { store.canvas(for: displayID) }

    func perform(_ command: any Command) {
        store.perform(command, on: displayID)
    }

    func showLive(_ element: (any Element)?, dirty: CGRect?) {
        live.show(element, dirty: dirty)
    }

    func setPendingRemoval(_ ids: Set<UUID>) {
        guard ids != pendingRemoval else { return }
        pendingRemoval = ids
        canvasDidChange()
    }

    // MARK: Cursor

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect, .cursorUpdate],
            owner: self
        ))
    }

    // DECISION: cursor rects only work in the key window, and our panel is often
    // not key, so the cursor is set explicitly from tracking/mouse events instead.
    private func applyCursor() {
        if isCapturing { tool.cursor.set() }
    }

    override func cursorUpdate(with event: NSEvent) { applyCursor() }
    override func mouseEntered(with event: NSEvent) { applyCursor() }
    override func mouseMoved(with event: NSEvent) {
        applyCursor()
        if isCapturing { tool.hover(InputPoint(event: event, in: self), context: self) }
    }
    override func mouseExited(with event: NSEvent) {
        if isCapturing { NSCursor.arrow.set() }
    }

    // MARK: Input

    override func mouseDown(with event: NSEvent) {
        guard isCapturing else { return super.mouseDown(with: event) }
        applyCursor()
        beginGesture(at: InputPoint(event: event, in: self))
    }

    override func mouseDragged(with event: NSEvent) {
        guard isCapturing, gestureActive else { return super.mouseDragged(with: event) }
        applyCursor()
        moveGesture(to: InputPoint(event: event, in: self))
    }

    override func mouseUp(with event: NSEvent) {
        guard isCapturing, gestureActive else { return super.mouseUp(with: event) }
        finishGesture(at: InputPoint(event: event, in: self))
    }

    override func flagsChanged(with event: NSEvent) {
        guard isCapturing else { return super.flagsChanged(with: event) }
        tool.modifiersChanged(event.modifierFlags, context: self)
    }

    func beginGesture(at point: InputPoint) {
        if gestureActive { endGesture() }
        gestureActive = true
        lastPoint = point
        tool.begin(point, context: self)
    }

    func moveGesture(to point: InputPoint) {
        lastPoint = point
        tool.move(point, context: self)
    }

    func finishGesture(at point: InputPoint) {
        lastPoint = point
        endGesture()
    }

    /// Finishes the gesture in progress, if any, at the last known point.
    private func endGesture() {
        guard gestureActive else { return }
        gestureActive = false
        if let lastPoint {
            tool.end(lastPoint, context: self)
        } else {
            tool.cancel(context: self)
        }
        lastPoint = nil
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
