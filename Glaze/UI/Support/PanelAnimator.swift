import AppKit

/// Shows and hides panels with the animation the user picked in Settings. The caller keeps a
/// generation counter and ignores completions from an older show/hide, so a quick toggle never
/// leaves a panel half-faded or ordered out while it should be visible.
@MainActor
enum PanelAnimator {
    /// Brings `window` on screen at `frame`. With a slide style it starts at `hidden` (just past
    /// its screen edge); with a fade style it starts transparent.
    static func show(_ window: NSWindow, to frame: NSRect, from hidden: NSRect?,
                     style: AnimationStyle, duration: TimeInterval, completion: @escaping () -> Void = {}) {
        let animate = style != .none && duration > 0
        window.setFrame(animate && style.slides ? (hidden ?? frame) : frame, display: false)
        window.alphaValue = animate && style.fades ? 0 : 1
        window.orderFrontRegardless()
        guard animate else { return completion() }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            if style.slides { window.animator().setFrame(frame, display: true) }
            window.animator().alphaValue = 1
        }, completionHandler: {
            MainActor.assumeIsolated { completion() }
        })
    }

    /// Animates `window` away. `completion` runs at the end (or at once with no animation); the
    /// caller orders the window out there.
    static func hide(_ window: NSWindow, to hidden: NSRect?, style: AnimationStyle,
                     duration: TimeInterval, completion: @escaping () -> Void) {
        guard style != .none, duration > 0, window.isVisible else { return completion() }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            if style.slides, let hidden { window.animator().setFrame(hidden, display: true) }
            if style.fades { window.animator().alphaValue = 0 }
        }, completionHandler: {
            MainActor.assumeIsolated { completion() }
        })
    }

    /// Fade-only variants for panels that stay where they are (color panel, notepad).
    static func fadeIn(_ window: NSWindow, style: AnimationStyle, duration: TimeInterval) {
        show(window, to: window.frame, from: nil, style: style == .none ? .none : .fade, duration: duration)
    }

    static func fadeOut(_ window: NSWindow, style: AnimationStyle, duration: TimeInterval, completion: @escaping () -> Void) {
        hide(window, to: nil, style: style == .none ? .none : .fade, duration: duration, completion: completion)
    }
}
