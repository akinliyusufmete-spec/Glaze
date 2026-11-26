import CoreGraphics
import Foundation

/// The built-in brushes, as data.
enum BrushPresets {
    /// Thin, light pressure response, small end taper.
    static let pen = BrushStyle(
        name: "Pen", baseWidth: 3,
        pressureCurve: .ease(exponent: 0.35),
        taper: Taper(end: 10)
    )

    /// Thick, flat ends, 90% opacity.
    static let marker = BrushStyle(
        name: "Marker", baseWidth: 12, opacity: 0.9,
        lineCap: .butt
    )

    /// Very thick, 35% opacity, multiply, straightens nearly straight strokes.
    static let highlighter = BrushStyle(
        name: "Highlighter", baseWidth: 24, opacity: 0.35, blendMode: .multiply,
        lineCap: .butt, autoStraighten: true
    )

    /// Jitter and grain, strong pressure response; widens when tilted.
    static let pencil = BrushStyle(
        name: "Pencil", baseWidth: 2.5, opacity: 0.85,
        pressureCurve: .ease(exponent: 1.8),
        taper: Taper(start: 2, end: 2),
        jitter: 0.6, grain: 0.5, tilt: .widen(factor: 1.5)
    )

    /// 45° nib; width follows stroke direction. Tilt turns the nib.
    static let calligraphy = BrushStyle(
        name: "Calligraphy", baseWidth: 10,
        pressureCurve: .ease(exponent: 0.6),
        taper: Taper(start: 4, end: 6),
        nibAngle: .pi / 4, tilt: .rotateNib
    )

    /// Colored blur with a bright white core.
    static let neon = BrushStyle(
        name: "Neon", baseWidth: 6,
        glow: Glow(radius: 12, coreColor: .white)
    )

    /// Dash pattern with round caps.
    // DECISION: 6pt dashes with 12pt gaps at 4pt width. Round caps add a
    // radius to each end, so the visible dash is ~10pt and the gap ~8pt.
    static let dashed = BrushStyle(
        name: "Dashed", baseWidth: 4,
        dash: [6, 12]
    )

    /// Neon look, never committed, fades over 0.8 s. Drawn by LaserTool (Phase 5).
    static let laser = BrushStyle(
        name: "Laser", baseWidth: 5,
        glow: Glow(radius: 10, coreColor: .white),
        isTransient: true, fadeDuration: 0.8
    )

    static let all: [BrushStyle] = [pen, marker, highlighter, pencil, calligraphy, neon, dashed, laser]

    /// A plain constant-width round stroke (used by legacy callers and tests).
    static func uniform(width: CGFloat) -> BrushStyle {
        BrushStyle(name: "Uniform", baseWidth: width)
    }

    /// The preset a brush tool uses, or nil for non-brush tools.
    static func preset(for id: ToolID) -> BrushStyle? {
        switch id {
        case .pen: pen
        case .marker: marker
        case .highlighter: highlighter
        case .pencil: pencil
        case .calligraphy: calligraphy
        case .neon: neon
        case .dashed: dashed
        case .laser: laser
        default: nil
        }
    }
}
