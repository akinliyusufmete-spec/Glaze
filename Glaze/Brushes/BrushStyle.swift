import CoreGraphics
import Foundation

/// Brushes are data, not subclasses: every brush is a `BrushStyle` that the
/// same `StrokeRenderer` reads.
struct BrushStyle: Codable, Hashable, Sendable {
    var name: String
    /// Full stroke width in points at full pressure.
    var baseWidth: CGFloat
    var opacity: CGFloat
    var blendMode: CGBlendMode
    var pressureCurve: PressureCurve
    var taper: Taper
    /// Calligraphy: the nib's angle in radians; width follows stroke direction.
    var nibAngle: CGFloat?
    var dash: [CGFloat]?
    var glow: Glow?
    /// Positional noise in points (pencil).
    var jitter: CGFloat
    /// Laser: never committed to the canvas.
    var isTransient: Bool
    var fadeDuration: TimeInterval?

    // DECISION: four fields beyond the spec's list. They are what the spec's
    // preset table asks for ("flat ends", "straightens automatically",
    // "grain texture", tilt as an input) and keeping them as data keeps
    // the renderer free of per-brush special cases.
    /// End shape for constant-width strokes (marker and highlighter are flat).
    var lineCap: CGLineCap
    /// Replace a nearly straight stroke with a straight line on release.
    var autoStraighten: Bool
    /// Strength (0…1) of the paper-grain texture knocked out of the stroke.
    var grain: CGFloat
    var tilt: TiltResponse

    init(
        name: String,
        baseWidth: CGFloat,
        opacity: CGFloat = 1,
        blendMode: CGBlendMode = .normal,
        pressureCurve: PressureCurve = .none,
        taper: Taper = .none,
        nibAngle: CGFloat? = nil,
        dash: [CGFloat]? = nil,
        glow: Glow? = nil,
        jitter: CGFloat = 0,
        isTransient: Bool = false,
        fadeDuration: TimeInterval? = nil,
        lineCap: CGLineCap = .round,
        autoStraighten: Bool = false,
        grain: CGFloat = 0,
        tilt: TiltResponse = .none
    ) {
        self.name = name
        self.baseWidth = baseWidth
        self.opacity = opacity
        self.blendMode = blendMode
        self.pressureCurve = pressureCurve
        self.taper = taper
        self.nibAngle = nibAngle
        self.dash = dash
        self.glow = glow
        self.jitter = jitter
        self.isTransient = isTransient
        self.fadeDuration = fadeDuration
        self.lineCap = lineCap
        self.autoStraighten = autoStraighten
        self.grain = grain
        self.tilt = tilt
    }

    /// True when every sample has the same width, so the renderer can stroke
    /// the centerline instead of filling an outline.
    var isUniformWidth: Bool {
        pressureCurve == .none && taper == .none && nibAngle == nil && jitter == 0
            && tilt == .none
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case name, baseWidth, opacity, blendMode, pressureCurve, taper, nibAngle, dash, glow
        case jitter, isTransient, fadeDuration, lineCap, autoStraighten, grain, tilt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        baseWidth = try c.decode(CGFloat.self, forKey: .baseWidth)
        opacity = try c.decode(CGFloat.self, forKey: .opacity)
        blendMode = CGBlendMode(rawValue: try c.decode(Int32.self, forKey: .blendMode)) ?? .normal
        pressureCurve = try c.decode(PressureCurve.self, forKey: .pressureCurve)
        taper = try c.decode(Taper.self, forKey: .taper)
        nibAngle = try c.decodeIfPresent(CGFloat.self, forKey: .nibAngle)
        dash = try c.decodeIfPresent([CGFloat].self, forKey: .dash)
        glow = try c.decodeIfPresent(Glow.self, forKey: .glow)
        jitter = try c.decode(CGFloat.self, forKey: .jitter)
        isTransient = try c.decode(Bool.self, forKey: .isTransient)
        fadeDuration = try c.decodeIfPresent(TimeInterval.self, forKey: .fadeDuration)
        // Extras are optional so hand-written custom brush JSON can omit them.
        let cap = try c.decodeIfPresent(Int32.self, forKey: .lineCap)
        lineCap = cap.flatMap { CGLineCap(rawValue: $0) } ?? .round
        autoStraighten = try c.decodeIfPresent(Bool.self, forKey: .autoStraighten) ?? false
        grain = try c.decodeIfPresent(CGFloat.self, forKey: .grain) ?? 0
        tilt = try c.decodeIfPresent(TiltResponse.self, forKey: .tilt) ?? .none
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(baseWidth, forKey: .baseWidth)
        try c.encode(opacity, forKey: .opacity)
        try c.encode(blendMode.rawValue, forKey: .blendMode)
        try c.encode(pressureCurve, forKey: .pressureCurve)
        try c.encode(taper, forKey: .taper)
        try c.encodeIfPresent(nibAngle, forKey: .nibAngle)
        try c.encodeIfPresent(dash, forKey: .dash)
        try c.encodeIfPresent(glow, forKey: .glow)
        try c.encode(jitter, forKey: .jitter)
        try c.encode(isTransient, forKey: .isTransient)
        try c.encodeIfPresent(fadeDuration, forKey: .fadeDuration)
        try c.encode(lineCap.rawValue, forKey: .lineCap)
        try c.encode(autoStraighten, forKey: .autoStraighten)
        try c.encode(grain, forKey: .grain)
        try c.encode(tilt, forKey: .tilt)
    }
}
