import AppKit
import SwiftUI

/// Shows a brief "Pointer" / "Draw · Pen" pill whenever the mode changes.
@MainActor
final class HUDController: ModeSink {
    private let preferences: Preferences
    private let panel: NSPanel
    private let hosting: NSHostingView<ModePillView>
    private var hideWork: DispatchWorkItem?
    private var generation = 0

    static let visibleDuration: TimeInterval = 1.2
    static let fadeDuration: TimeInterval = 0.25
    static let inset: CGFloat = 16

    init(preferences: Preferences) {
        self.preferences = preferences
        hosting = NSHostingView(rootView: ModePillView(mode: .pointer))
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.contentView = hosting
    }

    func apply(mode: AppMode, previous: AppMode?) {
        // `previous == nil` is the initial attach/resync — not a user action.
        guard previous != nil, preferences.showModeHUD else { return }
        show(mode)
    }

    private func show(_ mode: AppMode) {
        hideWork?.cancel()
        generation += 1
        let token = generation

        hosting.rootView = ModePillView(mode: mode)
        let size = hosting.fittingSize
        // DECISION: the HUD follows the mouse's screen, since that's where the
        // user is looking; fall back to the main screen.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let origin = NSPoint(
            x: visible.maxX - size.width - Self.inset,
            y: visible.maxY - size.height - Self.inset
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.fadeOut(token: token) }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.visibleDuration, execute: work)
    }

    private func fadeOut(token: Int) {
        guard token == generation else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, token == self.generation else { return }
                self.panel.orderOut(nil)
            }
        }
    }
}
