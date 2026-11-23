import AppKit

/// Phase 1 stand-in canvas: a fixed red 4 pt pen drawn with NSBezierPath.
///
/// DECISION: Phase 1 only needs "in Draw mode you can draw", so this view keeps
/// finished strokes as plain bezier paths. Phase 2 replaces it with the real
/// stroke model + CALayer renderer; nothing outside this file depends on the
/// internals beyond `isCapturing`, `onEscape` and `clear()`.
@MainActor
final class CanvasView: NSView {
    var isCapturing = false {
        didSet {
            guard isCapturing != oldValue else { return }
            if !isCapturing { finishStroke() }
            window?.invalidateCursorRects(for: self)
        }
    }

    /// Called when Esc is pressed while capturing.
    var onEscape: (() -> Void)?

    private var strokes: [NSBezierPath] = []
    private var current: NSBezierPath?
    private let strokeColor = NSColor.systemRed
    private let strokeWidth: CGFloat = 4
    private lazy var cursor = BrushCursor.make(diameter: strokeWidth, color: strokeColor)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    // DECISION: the canvas never asks the panel to become key in Phase 1. Mouse
    // input reaches a non-key panel anyway (acceptsFirstMouse), and Esc arrives
    // through a global hotkey registered only while drawing (see Hotkeys), so the
    // front app keeps keyboard focus the whole time. Later tools that need typing
    // (text) can flip this on; FocusRestorer already hands key status back.
    override var needsPanelToBecomeKey: Bool { false }

    func clear() {
        strokes.removeAll()
        current = nil
        needsDisplay = true
    }

    var hasContent: Bool { !strokes.isEmpty || current != nil }

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
        if isCapturing { cursor.set() }
    }

    override func cursorUpdate(with event: NSEvent) { applyCursor() }
    override func mouseEntered(with event: NSEvent) { applyCursor() }
    override func mouseMoved(with event: NSEvent) { applyCursor() }
    override func mouseExited(with event: NSEvent) {
        if isCapturing { NSCursor.arrow.set() }
    }

    // MARK: Drawing input

    override func mouseDown(with event: NSEvent) {
        guard isCapturing else { return super.mouseDown(with: event) }
        applyCursor()
        let path = NSBezierPath()
        path.lineWidth = strokeWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: convert(event.locationInWindow, from: nil))
        current = path
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isCapturing, let current else { return super.mouseDragged(with: event) }
        applyCursor()
        current.line(to: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isCapturing else { return super.mouseUp(with: event) }
        finishStroke()
    }

    private func finishStroke() {
        guard let current else { return }
        if current.elementCount == 1 {
            // A click with no drag: record a dot.
            let point = current.currentPoint
            current.line(to: NSPoint(x: point.x + 0.01, y: point.y))
        }
        strokes.append(current)
        self.current = nil
        needsDisplay = true
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

    override func draw(_ dirtyRect: NSRect) {
        strokeColor.setStroke()
        for path in strokes where path.bounds.insetBy(dx: -strokeWidth, dy: -strokeWidth).intersects(dirtyRect) {
            path.stroke()
        }
        current?.stroke()
    }
}
