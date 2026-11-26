#if DEBUG
import AppKit

/// DEBUG-only hooks for benchmarks, presets demos and snapshots.
extension CanvasView {
    enum DebugPhase { case begin, move, end }

    /// Feeds a synthetic gesture point straight to the tool, through the same
    /// path mouse events take.
    func debugInput(_ phase: DebugPhase, at location: CGPoint, pressure: CGFloat = 1) {
        let point = InputPoint(location: location, pressure: pressure, timestamp: ProcessInfo.processInfo.systemUptime)
        switch phase {
        case .begin: beginGesture(at: point)
        case .move: moveGesture(to: point)
        case .end: finishGesture(at: point)
        }
    }

    /// Runs any pending committed render and live repaint now.
    func debugFlush() {
        updateLayer()
        live.flush()
    }

    func debugForceFullRender() {
        committed.render(canvas, hiding: pendingRemoval, forceFull: true)
        committedDirty = false
    }

    /// Writes the committed bitmap with the live element on top as a PNG.
    func debugSnapshot(to url: URL) -> Bool {
        debugFlush()
        guard let base = committed.makeImage() else { return false }
        return DebugBench.writePNG(base: base, live: live.element, scale: window?.backingScaleFactor ?? 2, to: url)
    }
}
#endif
