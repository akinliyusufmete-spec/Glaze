import AppKit
import QuartzCore

/// A laser pointer: a red dot with a glowing trail that follows the pointer (button down or not)
/// and fades away shortly after the pointer stops. Nothing is committed to the canvas, so it never
/// appears in undo history. The trail lives on the live layer and is redrawn by a timer.
@MainActor
final class LaserTool: Tool {
    let id: ToolID = .laser

    /// The laser is red whatever color is picked for drawing.
    static let color = NSColor(srgbRed: 1, green: 0.16, blue: 0.16, alpha: 1)
    static let frameInterval: TimeInterval = 1.0 / 60
    /// Keeps a very long pause-free drag from growing the point list without bound.
    static let maxPoints = 240

    private let settings: ToolSettings?
    private var points: [(location: CGPoint, time: TimeInterval)] = []
    private var timer: Timer?
    private weak var context: (any ToolContext)?

    private(set) lazy var cursor: NSCursor = LaserCursor.make()

    init(settings: ToolSettings? = nil) {
        self.settings = settings
    }

    /// Seconds the trail takes to fade after the pointer stops (Settings → General).
    var fadeDuration: TimeInterval { settings?.laserFadeDuration ?? BrushPresets.laser.fadeDuration ?? 0.8 }
    private var width: CGFloat { BrushPresets.laser.baseWidth }

    var isShowing: Bool { !points.isEmpty }

    // MARK: Tool

    func begin(_ point: InputPoint, context: any ToolContext) { track(point.location, context: context) }
    func move(_ point: InputPoint, context: any ToolContext) { track(point.location, context: context) }
    func hover(_ point: InputPoint, context: any ToolContext) { track(point.location, context: context) }

    /// Letting go doesn't clear the trail: it fades out on its own.
    func end(_ point: InputPoint, context: any ToolContext) { track(point.location, context: context) }

    func cancel(context: any ToolContext) { clear(context: context) }
    func deactivate(context: any ToolContext) { clear(context: context) }

    // MARK: Trail

    private func track(_ location: CGPoint, context: any ToolContext) {
        self.context = context
        let now = CACurrentMediaTime()
        if let last = points.last, hypot(last.location.x - location.x, last.location.y - location.y) < 0.5 {
            // The pointer hasn't really moved: keep the trail fading rather than refreshing its head.
            startTimer()
            return
        }
        points.append((location, now))
        if points.count > Self.maxPoints { points.removeFirst(points.count - Self.maxPoints) }
        render(at: now)
        startTimer()
    }

    private func tick() {
        guard let context else { return stopTimer() }
        let now = CACurrentMediaTime()
        prune(at: now)
        if points.isEmpty {
            stopTimer()
            context.showLive(nil, dirty: nil)
        } else {
            render(at: now)
        }
    }

    private func prune(at now: TimeInterval) {
        let life = fadeDuration
        points.removeAll { now - $0.time >= life }
    }

    private func render(at now: TimeInterval) {
        guard let context else { return }
        let trail = LaserTrailElement(
            points: points.map { .init(location: $0.location, age: now - $0.time) },
            life: fadeDuration, color: Self.color.cgColor, width: width
        )
        context.showLive(trail, dirty: nil)   // a new id each frame, so the layer repaints old and new bounds
    }

    private func clear(context: any ToolContext) {
        stopTimer()
        points = []
        context.showLive(nil, dirty: nil)
    }

    // MARK: Timer

    private func startTimer() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.frameInterval, repeats: true) { [weak self] timer in
            // If the tool was dropped without `deactivate`, don't let the timer outlive it.
            guard let self else { return timer.invalidate() }
            MainActor.assumeIsolated { self.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
