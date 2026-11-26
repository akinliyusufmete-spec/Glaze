import AppKit
import SwiftUI

/// Shows one hover hint at a time in its own click-through panel, so a hint can extend past the
/// edge of the small toolbar window that triggered it.
@MainActor
final class HintCenter {
    private let preferences: Preferences
    private let panel: NSPanel
    private let host = NSHostingView(rootView: AnyView(EmptyView()))
    private var pending: DispatchWorkItem?
    private var shown = false

    /// Which screen edge the toolbar is on decides which side of the pointer the hint opens on
    /// (away from the edge), so it never covers the toolbar.
    var dockEdge: () -> DockEdge? = { nil }

    init(preferences: Preferences) {
        self.preferences = preferences
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = WindowLevels(coverFullScreenGames: preferences.drawOverFullScreenGames).hint
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.contentView = host
    }

    func setLevel(_ level: NSWindow.Level) { panel.level = level }

    /// Shows `hint` once the pointer has rested for the configured delay.
    func schedule(_ hint: Hint) {
        cancel()
        guard preferences.hintsEnabled else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.show(hint) }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + preferences.hintDelay, execute: work)
    }

    /// Hides the hint and cancels one that hasn't appeared yet.
    func cancel() {
        pending?.cancel()
        pending = nil
        guard shown else { return }
        shown = false
        panel.orderOut(nil)
    }

    private func show(_ hint: Hint) {
        host.rootView = AnyView(HintBubble(hint: hint))
        let size = host.fittingSize
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.frame ?? CGRect(origin: .zero, size: size)
        panel.setFrame(Self.frame(for: size, near: mouse, edge: dockEdge(), in: visible), display: true)
        panel.orderFrontRegardless()
        shown = true
    }

    /// Where the bubble goes: offset from the pointer, away from the dock edge, and kept on screen.
    static func frame(for size: CGSize, near mouse: CGPoint, edge: DockEdge?, in visible: CGRect) -> CGRect {
        let gap: CGFloat = 18
        var origin: CGPoint
        switch edge {
        case .bottom: origin = CGPoint(x: mouse.x - size.width / 2, y: mouse.y + gap)               // above
        case .left: origin = CGPoint(x: mouse.x + gap, y: mouse.y - size.height / 2)                 // to the right
        case .right: origin = CGPoint(x: mouse.x - gap - size.width, y: mouse.y - size.height / 2)   // to the left
        case .top, .none: origin = CGPoint(x: mouse.x - size.width / 2, y: mouse.y - gap - size.height) // below
        }
        origin.x = max(visible.minX + 4, min(origin.x, visible.maxX - size.width - 4))
        origin.y = max(visible.minY + 4, min(origin.y, visible.maxY - size.height - 4))
        return CGRect(origin: origin, size: size)
    }
}
