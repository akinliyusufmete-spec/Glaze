import AppKit
import QuartzCore

/// The live half of the committed/live split: the one element being drawn
/// right now. Each mouse event repaints only the rect the tool says changed,
/// so its cost depends on the stroke being drawn, never on what's already on
/// the canvas.
@MainActor
final class LiveLayer: NSObject, CALayerDelegate {
    let layer = CALayer()

    private(set) var element: (any Element)?

    override init() {
        super.init()
        layer.delegate = self
        layer.isOpaque = false
        layer.needsDisplayOnBoundsChange = true
        layer.actions = [
            "contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "frame": NSNull(),
        ]
    }

    /// Shows `element` (nil hides it). `dirty` is the canvas rect that changed
    /// since the last call; when unknown, the old and new bounds are repainted.
    func show(_ element: (any Element)?, dirty: CGRect?) {
        let old = self.element
        self.element = element
        if old?.id != element?.id { updateCompositing(for: element) }
        // DECISION: hiding invalidates only the old element's area instead of
        // dropping `contents`, so the backing store is reused by the next stroke
        // rather than reallocated (a full-screen buffer) on every mouse-down.
        var rect = dirty ?? .null
        if dirty == nil || old?.id != element?.id {
            rect = rect.union(old?.bounds ?? .null).union(element?.bounds ?? .null)
        }
        guard !rect.isNull, !rect.isEmpty else { return }
        layer.setNeedsDisplay(rect.insetBy(dx: -1, dy: -1))
    }

    /// The live layer is its own surface, so a blend mode drawn into it would
    /// blend with transparent pixels, not with the committed strokes below.
    // DECISION: multiply strokes set the layer's compositing filter instead,
    // so a highlighter darkens what's under it while it's being drawn, the
    // same way it does once committed. Other blend modes preview as normal.
    private func updateCompositing(for element: (any Element)?) {
        let filter: String? = element?.blendMode == .multiply ? "multiplyBlendMode" : nil
        guard (layer.compositingFilter as? String) != filter else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.compositingFilter = filter
        CATransaction.commit()
    }

    /// Paints any pending invalidation now (benchmarks and snapshots).
    func flush() {
        layer.displayIfNeeded()
    }

    nonisolated func draw(_ layer: CALayer, in context: CGContext) {
        // Core Animation calls this synchronously on the main thread during
        // display, so the context never actually crosses threads.
        nonisolated(unsafe) let ctx = context
        MainActor.assumeIsolated {
            // Partial updates reuse the old backing store, so clear what's being redrawn.
            ctx.clear(ctx.boundingBoxOfClipPath)
            guard let element else { return }
            ctx.setShouldAntialias(true)
            element.draw(in: ctx)
        }
    }

    /// Core Animation's default actions would fade every update; drawing must be instant.
    nonisolated func action(for layer: CALayer, forKey event: String) -> (any CAAction)? {
        NSNull()
    }
}
