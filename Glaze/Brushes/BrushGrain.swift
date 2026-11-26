import CoreGraphics
import Foundation

/// A small tileable noise texture knocked out of pencil strokes so they read
/// as graphite on paper rather than ink.
enum BrushGrain {
    /// Tile size in pixels.
    static let tileSize = 64

    static let tile: CGImage? = makeTile()

    /// Removes up to `strength` of the alpha already drawn in `rect`, in a
    /// fixed per-pixel pattern. Call inside a transparency layer that holds
    /// only the stroke, so the grain can't punch through content below.
    static func apply(strength: CGFloat, in rect: CGRect, context: CGContext) {
        guard strength > 0, let tile, !rect.isNull, !rect.isEmpty else { return }
        context.saveGState()
        context.clip(to: rect)
        context.setBlendMode(.destinationOut)
        context.setAlpha(min(strength, 1))
        // DECISION: one texel per device pixel at any zoom, so grain looks like
        // paper tooth instead of magnifying into blotches.
        let ctm = context.ctm
        let scale = max(hypot(ctm.a, ctm.b), 0.01)
        let side = CGFloat(tileSize) / scale
        context.draw(tile, in: CGRect(x: 0, y: 0, width: side, height: side), byTiling: true)
        context.restoreGState()
    }

    private static func makeTile() -> CGImage? {
        let n = tileSize
        var noise = SeededNoise(seed: 0x6C61_7A65_6772_6169)
        var bytes = [UInt8](repeating: 0, count: n * n * 4)
        for i in 0..<(n * n) {
            // DECISION: about 45% of texels knock anything out, with varying
            // depth; the rest leave the stroke solid. Reads as sparse tooth.
            let v = (noise.nextUnit() - 0.1) * 1.4
            let alpha = UInt8(max(0, min(1, v)) * 255)
            // Premultiplied black: only alpha matters for destinationOut.
            bytes[i * 4 + 3] = alpha
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(
            width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
            space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}
