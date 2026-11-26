import SwiftUI

/// What a hover hint says: a title, an optional line of explanation, and the keyboard shortcut of
/// a catalog action (looked up when the hint appears, so rebinding is reflected immediately).
struct Hint: Equatable {
    var title: String
    var detail: String?
    var actionID: String?

    init(title: String, detail: String? = nil, actionID: String? = nil) {
        self.title = title
        self.detail = detail
        self.actionID = actionID
    }

    /// A hint for a catalog action: its title, detail and live shortcut.
    init(action id: String) {
        let action = ShortcutCatalog.action(id)
        self.init(title: action?.title ?? id, detail: action?.detail, actionID: id)
    }

    /// The shortcut line: the binding, "Not set" if the user cleared it, or `nil` when the hint
    /// isn't about a catalog action.
    var shortcutLine: String? {
        guard let id = actionID, let action = ShortcutCatalog.action(id) else { return nil }
        return action.shortcutText ?? "No shortcut set"
    }
}

private struct HintCenterKey: EnvironmentKey {
    static let defaultValue: HintCenter? = nil
}

extension EnvironmentValues {
    var hintCenter: HintCenter? {
        get { self[HintCenterKey.self] }
        set { self[HintCenterKey.self] = newValue }
    }
}

extension View {
    /// Shows `hint` in a floating bubble when the pointer rests on this view.
    func hint(_ hint: Hint) -> some View { modifier(HintModifier(hint: hint)) }

    func hint(action id: String) -> some View { modifier(HintModifier(hint: Hint(action: id))) }
}

private struct HintModifier: ViewModifier {
    let hint: Hint
    @Environment(\.hintCenter) private var center

    func body(content: Content) -> some View {
        content.background(HoverTracker { inside in
            if inside { center?.schedule(hint) } else { center?.cancel() }
        })
    }
}

/// Reports the pointer entering and leaving a view, using an AppKit tracking area with
/// `.activeAlways`. SwiftUI's own `onHover` can stay silent in windows that aren't active, and
/// Glaze's panels never activate the app, so hints need this.
struct HoverTracker: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> TrackerView { TrackerView() }

    func updateNSView(_ view: TrackerView, context: Context) { view.onChange = onChange }

    final class TrackerView: NSView {
        var onChange: ((Bool) -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }      // never blocks clicks

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        }

        override func mouseEntered(with event: NSEvent) { onChange?(true) }
        override func mouseExited(with event: NSEvent) { onChange?(false) }
    }
}
