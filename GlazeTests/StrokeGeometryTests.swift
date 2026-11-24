import XCTest
@testable import Glaze

final class StrokeGeometryTests: XCTestCase {
    private func line(pressure: CGFloat, count: Int = 30, tilt: CGVector = .zero) -> [InputPoint] {
        (0..<count).map { i in
            InputPoint(location: CGPoint(x: 20 + CGFloat(i) * 5, y: 50), pressure: pressure, tilt: tilt)
        }
    }

    private func midRadius(_ g: StrokeGeometry) -> CGFloat { g.radii[g.radii.count / 2] }

    func testHigherPressureGivesWiderStroke() {
        let light = StrokeGeometry(samples: line(pressure: 0.2), style: BrushPresets.pen, seed: 1)
        let heavy = StrokeGeometry(samples: line(pressure: 1), style: BrushPresets.pen, seed: 1)
        XCTAssertGreaterThan(midRadius(heavy), midRadius(light) * 1.5)
    }

    func testUniformStyleHasEqualRadii() throws {
        let g = StrokeGeometry(samples: line(pressure: 0.3), style: BrushPresets.uniform(width: 6), seed: 1)
        XCTAssertTrue(g.isUniform)
        let first = try XCTUnwrap(g.radii.first)
        XCTAssertEqual(first, 3, accuracy: 1e-9)
        XCTAssertTrue(g.radii.allSatisfy { abs($0 - first) < 1e-9 })
    }

    func testOnlyCalligraphyHasANib() {
        XCTAssertNotNil(StrokeGeometry(samples: line(pressure: 1), style: BrushPresets.calligraphy, seed: 1).nibVectors)
        XCTAssertNil(StrokeGeometry(samples: line(pressure: 1), style: BrushPresets.pen, seed: 1).nibVectors)
    }

    func testSameSeedIsDeterministic() {
        let a = StrokeGeometry(samples: line(pressure: 0.7), style: BrushPresets.pencil, seed: 42)
        let b = StrokeGeometry(samples: line(pressure: 0.7), style: BrushPresets.pencil, seed: 42)
        XCTAssertEqual(a.points, b.points)
        XCTAssertEqual(a.radii, b.radii)
    }

    func testSignedAreaOfUnitSquare() {
        let square = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)]
        XCTAssertEqual(abs(StrokeOutline.signedArea(square)), 1, accuracy: 1e-9)
        XCTAssertEqual(StrokeOutline.signedArea(square), -StrokeOutline.signedArea(square.reversed()), accuracy: 1e-9)
    }

    // MARK: Pixels

    private func render(size: CGSize = CGSize(width: 200, height: 100), background: CGColor? = nil,
                        _ strokes: [StrokeElement]) -> (pixels: [UInt8], width: Int) {
        let w = Int(size.width), h = Int(size.height)
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(
                data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            if let background {
                ctx.setFillColor(background)
                ctx.fill(CGRect(origin: .zero, size: size))
            }
            strokes.forEach { $0.draw(in: ctx) }
        }
        return (pixels, w)
    }

    /// Total ink: summed alpha. A pixel-count threshold would hide sub-pixel
    /// width changes (a 1.7 px and a 3 px line can cover the same rows).
    private func ink(_ pixels: [UInt8]) -> Int {
        stride(from: 3, to: pixels.count, by: 4).reduce(0) { $0 + Int(pixels[$1]) }
    }

    func testPressureChangesRenderedWidth() {
        let color = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        let light = render([StrokeElement(samples: line(pressure: 0.1), style: BrushPresets.pen, color: color)])
        let heavy = render([StrokeElement(samples: line(pressure: 1), style: BrushPresets.pen, color: color)])
        // The pen's light curve gives 0.1^0.35 ≈ 0.45 of full width at 10% pressure.
        XCTAssertGreaterThan(ink(heavy.pixels), ink(light.pixels) * 3 / 2)
    }

    func testHighlighterDarkensWhatIsUnderIt() {
        let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let black = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        let yellow = CGColor(srgbRed: 1, green: 0.9, blue: 0, alpha: 1)
        let ink = StrokeElement(samples: line(pressure: 1), style: BrushPresets.uniform(width: 4), color: black)
        let highlight = StrokeElement(samples: line(pressure: 1), style: BrushPresets.highlighter, color: yellow)
        let (pixels, width) = render(background: white, [ink, highlight])
        // Row 50 from the bottom; bitmap rows run top-down.
        let center = ((100 - 1 - 50) * width + 90) * 4
        XCTAssertLessThan(pixels[center], 40, "multiply keeps the black line black")
        XCTAssertLessThan(pixels[center + 1], 40)
        // Off the ink but under the highlighter: tinted, not white.
        let beside = ((100 - 1 - 56) * width + 90) * 4
        XCTAssertGreaterThan(pixels[beside], 200)
        XCTAssertLessThan(pixels[beside + 2], 200, "yellow multiplied onto white drops the blue channel")
    }

    /// Joints between segments of different radius must not leave sub-pixel
    /// slivers: inside a translucent stroke they show as lighter columns.
    func testVariableWidthStrokeHasNoSeams() {
        let color = CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
        let spacings: [CGFloat] = [9.3, 14]
        let cases: [(BrushStyle, CGFloat)] = [BrushPresets.marker, BrushPresets.pen].flatMap { style in
            spacings.map { (style, $0) }
        }
        for (style, spacing) in cases {
            var samples = (0..<40).map { i in
                InputPoint(location: CGPoint(x: 20 + CGFloat(i) * spacing, y: 50))
            }
            for i in samples.indices { samples[i].pressure = 0.1 + 0.9 * CGFloat(i) / 39 }
            let (pixels, width) = render(size: CGSize(width: 600, height: 100),
                                         [StrokeElement(samples: samples, style: style, color: color)])
            let alpha = { (x: Int, y: Int) in Int(pixels[(y * width + x) * 4 + 3]) }
            let full = (0..<pixels.count / 4).map { Int(pixels[$0 * 4 + 3]) }.max() ?? 0
            XCTAssertGreaterThan(full, 0)
            // A seam pixel is lighter than full ink while both horizontal neighbours are full.
            var seams: [CGPoint] = []
            for y in 0..<100 {
                for x in 1..<(width - 1) where alpha(x - 1, y) >= full - 1 && alpha(x + 1, y) >= full - 1
                    && alpha(x, y) < full - 1 {
                    seams.append(CGPoint(x: x, y: y))
                }
            }
            XCTAssertEqual(seams, [], "lighter columns in \(style.name) at spacing \(spacing)")
        }
    }
}
