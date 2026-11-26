import AppKit
import SwiftUI

/// The small tab on the screen edge that reveals the toolbar when tapped (the "iOS Dock" mode).
@MainActor
final class EdgeHandleController {
    private let preferences: Preferences
    private let hints: HintCenter
    private let panel = HandlePanel()
    private let host = NSHostingView(rootView: AnyView(EmptyView()))
    private var wantsVisible = false
    private var generation = 0

    /// Called when the handle is tapped.
    var onTap: (() -> Void)?

    init(preferences: Preferences, hints: HintCenter) {
        self.preferences = preferences
        self.hints = hints
        panel.contentView = host
        relayout()
    }

    private var edge: DockEdge { preferences.toolbarPlacement.edge ?? .top }

    func setLevel(_ level: NSWindow.Level) { panel.level = level }

    /// Rebuilds the handle for the current edge and moves it there.
    func relayout() {
        host.rootView = AnyView(
            EdgeHandleView(edge: edge) { [weak self] in self?.onTap?() }
                .environment(\.hintCenter, hints)
        )
        let frame = shownFrame()
        panel.setContentSize(frame.size)
        if wantsVisible { panel.setFrame(frame, display: true) }
    }

    func setVisible(_ visible: Bool, animated: Bool) {
        guard visible != wantsVisible || (visible && !panel.isVisible) else { return }
        wantsVisible = visible
        generation += 1
        let current = generation
        hints.cancel()

        let target = shownFrame()
        let hidden = DockGeometry.hiddenFrame(from: target, edge: edge)
        let style = animated ? preferences.animationStyle : .none
        if visible {
            PanelAnimator.show(panel, to: target, from: hidden, style: style, duration: preferences.animationDuration)
        } else {
            PanelAnimator.hide(panel, to: hidden, style: style, duration: preferences.animationDuration) { [weak self] in
                guard let self, self.generation == current else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
            }
        }
    }

    private func shownFrame() -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        return DockGeometry.handleFrame(edge: edge, in: screen?.visibleFrame ?? .zero)
    }
}

final class HandlePanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .glazePanel
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

struct EdgeHandleView: View {
    let edge: DockEdge
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        let vertical = edge.isVertical
        ZStack {
            Capsule()
                .fill(Color.primary.opacity(hovering ? 0.6 : 0.35))
                .frame(width: vertical ? 5 : DockGeometry.handleLength - 16, height: vertical ? DockGeometry.handleLength - 16 : 5)
        }
        .frame(width: vertical ? DockGeometry.handleThickness : DockGeometry.handleLength,
               height: vertical ? DockGeometry.handleLength : DockGeometry.handleThickness)
        .background(.regularMaterial, in: Capsule())
        .contentShape(Rectangle())
        .background(HoverTracker { hovering = $0 })
        .onTapGesture(perform: onTap)
        .hint(Hint(title: "Show toolbar", detail: "Tap to bring the toolbar out.", actionID: "toggleToolbar"))
    }
}
