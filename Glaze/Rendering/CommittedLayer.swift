import AppKit
import QuartzCore

/// The committed half of the committed/live split: every finished element,
/// rasterized into a bitmap that is only touched when the canvas changes.
///
/// Drawing a new stroke paints just that stroke on top of the cached bitmap;
/// undo, erase and other removals clear and repaint only the area they affect.
/// Nothing here runs per mouse event, so frame rate doesn't depend on how many
/// strokes are on screen.
@MainActor
final class CommittedLayer {
    let layer = CALayer()

    private var context: CGContext?
    private var pixelSize: CGSize = .zero
    private var pointSize: CGSize = .zero
    private var scale: CGFloat = 1

    /// What the bitmap currently shows, bottom to top.
    private var drawnIDs: [UUID] = []
    private var drawnBounds: [UUID: CGRect] = [:]

    init() {
        layer.actions = [
            "contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "frame": NSNull(),
        ]
        layer.contentsGravity = .resize
        layer.isOpaque = false
    }

    /// Matches the bitmap to the view. Reallocating forces a full repaint on the next render.
    func resize(to size: CGSize, scale: CGFloat) {
        guard size != pointSize || scale != self.scale else { return }
        pointSize = size
        self.scale = scale
        layer.contentsScale = scale
        pixelSize = CGSize(width: (size.width * scale).rounded(.up), height: (size.height * scale).rounded(.up))
        context = Self.makeContext(pixelSize: pixelSize, scale: scale)
        drawnIDs = []
        drawnBounds = [:]
        layer.contents = nil
    }

    /// Brings the bitmap up to date with `canvas`, leaving out `hidden` elements.
    func render(_ canvas: Canvas, hiding hidden: Set<UUID> = [], forceFull: Bool = false) {
        guard let context else { return }
        let visible = hidden.isEmpty ? canvas.elements : canvas.elements.filter { !hidden.contains($0.id) }
        let ids = visible.map(\.id)

        if !forceFull, ids.count >= drawnIDs.count, ids.starts(with: drawnIDs) {
            // Appended only (the common case: a stroke was just committed).
            guard ids.count > drawnIDs.count else { return }
            for element in visible[drawnIDs.count...] { element.draw(in: context) }
        } else if !forceFull, let dirty = changedArea(newIDs: ids, visible: visible) {
            repaint(dirty, with: visible, in: context)
        } else {
            repaint(CGRect(origin: .zero, size: pointSize), with: visible, in: context)
        }

        drawnIDs = ids
        drawnBounds = Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0.bounds) })
        layer.contents = context.makeImage()
    }

    /// The current bitmap, for debug snapshots.
    func makeImage() -> CGImage? { context?.makeImage() }

    // MARK: Private

    /// The union of the bounds of elements that appeared or disappeared, or nil
    /// when a full repaint is needed (e.g. the same elements in a new order).
    private func changedArea(newIDs: [UUID], visible: [any Element]) -> CGRect? {
        let oldSet = Set(drawnIDs)
        let newSet = Set(newIDs)
        guard oldSet != newSet else { return nil }
        // Elements that stay must keep their relative order, or the overlap would paint wrong.
        guard drawnIDs.filter(newSet.contains) == newIDs.filter(oldSet.contains) else { return nil }
        var dirty = CGRect.null
        for id in oldSet.subtracting(newSet) {
            dirty = dirty.union(drawnBounds[id] ?? .null)
        }
        for element in visible where !oldSet.contains(element.id) {
            dirty = dirty.union(element.bounds)
        }
        return dirty.isNull ? nil : dirty
    }

    private func repaint(_ rect: CGRect, with elements: [any Element], in context: CGContext) {
        // Snap outward to whole device pixels so antialiased edges are fully redrawn.
        let area = CGRect(
            x: floor(rect.minX * scale) / scale - 1, y: floor(rect.minY * scale) / scale - 1,
            width: ceil(rect.width * scale) / scale + 2, height: ceil(rect.height * scale) / scale + 2
        ).intersection(CGRect(origin: .zero, size: pointSize))
        guard !area.isNull, !area.isEmpty else { return }
        context.saveGState()
        context.clip(to: area)
        context.clear(area)
        for element in elements where element.bounds.intersects(area) {
            element.draw(in: context)
        }
        context.restoreGState()
    }

    private static func makeContext(pixelSize: CGSize, scale: CGFloat) -> CGContext? {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }
        // DECISION: Display P3, premultiplied BGRA — the native format of Mac
        // displays, so Core Animation can show the bitmap without converting it.
        let space = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: nil, width: Int(pixelSize.width), height: Int(pixelSize.height),
            bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info
        ) else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.setShouldAntialias(true)
        context.interpolationQuality = .high
        return context
    }
}
