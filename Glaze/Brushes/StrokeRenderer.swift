import CoreGraphics
import Foundation

/// Paints any stroke from its geometry and brush. Every brush goes through
/// here; differences between brushes come only from `BrushStyle` data.
enum StrokeRenderer {
    /// Draws `geometry` in `color`. The caller has already applied the
    /// element's transform, so everything here is in local coordinates.
    static func draw(_ geometry: StrokeGeometry, color: CGColor, in context: CGContext) {
        guard !geometry.points.isEmpty else { return }
        let clip = context.boundingBoxOfClipPath
        guard geometry.localBounds.intersects(clip) else { return }
        let style = geometry.style

        context.saveGState()
        defer { context.restoreGState() }
        // Opacity and blend apply once to the whole stroke: overlapping parts
        // of one stroke never double up.
        context.setAlpha(style.opacity)
        context.setBlendMode(style.blendMode)

        if let glow = style.glow {
            // Shadow blur is in device space; scale it so glow tracks zoom.
            let scale = hypot(context.ctm.a, context.ctm.b)
            context.setShadow(offset: .zero, blur: glow.radius * scale, color: color)
            // DECISION: the layer is bounded to the stroke plus twice the glow
            // radius (the blur's visible reach), not the whole clip; an
            // unbounded layer composites a full-screen buffer per stroke.
            let glowBounds = geometry.localBounds.insetBy(dx: -2 * glow.radius, dy: -2 * glow.radius)
            context.beginTransparencyLayer(in: glowBounds.intersection(clip), auxiliaryInfo: nil)
            paintBody(geometry, color: color, radiusScale: 1, clip: clip, in: context)
            paintBody(geometry, color: glow.coreColor.cgColor,
                      radiusScale: Glow.coreWidthFraction, clip: clip, in: context)
            context.endTransparencyLayer()
        } else if style.grain > 0 {
            let grainBounds = geometry.localBounds.intersection(clip)
            context.beginTransparencyLayer(in: grainBounds, auxiliaryInfo: nil)
            paintBody(geometry, color: color, radiusScale: 1, clip: clip, in: context)
            BrushGrain.apply(strength: style.grain, in: grainBounds, context: context)
            context.endTransparencyLayer()
        } else {
            paintBody(geometry, color: color, radiusScale: 1, clip: clip, in: context)
        }
    }

    /// The solid shape: a stroked centerline for uniform/dashed brushes, a
    /// filled outline otherwise.
    private static func paintBody(
        _ geometry: StrokeGeometry, color: CGColor, radiusScale: CGFloat,
        clip: CGRect, in context: CGContext
    ) {
        let style = geometry.style
        if geometry.isUniform {
            context.setStrokeColor(color)
            context.setLineWidth(style.baseWidth * radiusScale)
            // A butt-capped click would be invisible; square caps make it a dot.
            let isDot = geometry.points.count == 1
            context.setLineCap(isDot && style.lineCap == .butt ? .square : style.lineCap)
            context.setLineJoin(.round)
            if let dash = style.dash, !dash.isEmpty {
                // DECISION: dash lengths are in points along the centerline and
                // don't scale with width, matching the preset's [6, 12] spec.
                context.setLineDash(phase: 0, lengths: dash)
            }
            context.addPath(geometry.centerline)
            context.strokePath()
        } else {
            context.setFillColor(color)
            context.addPath(geometry.outline(radiusScale: radiusScale, clip: clip))
            // Outline subpaths all wind the same way, so nonzero unions them.
            context.fillPath(using: .winding)
        }
    }
}
