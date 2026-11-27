import Foundation

/// A screen edge the toolbar can dock to.
enum DockEdge: String, CaseIterable, Identifiable, Sendable {
    case top, bottom, left, right

    var id: String { rawValue }
    var isVertical: Bool { self == .left || self == .right }
    var title: String { rawValue.capitalized }
}

/// Where the toolbar sits.
enum ToolbarPlacement: String, CaseIterable, Identifiable, Sendable {
    case top, bottom, left, right
    /// Not attached to an edge: the user drags it anywhere.
    case floating

    var id: String { rawValue }
    /// The edge it docks to, or `nil` when floating.
    var edge: DockEdge? { DockEdge(rawValue: rawValue) }
    var isVertical: Bool { edge?.isVertical ?? false }
    var title: String { self == .floating ? "Floating (drag anywhere)" : rawValue.capitalized }
}

/// How the toolbar is brought up while drawing.
enum ToolbarReveal: String, CaseIterable, Identifiable, Sendable {
    /// Visible whenever Draw mode is on.
    case always
    /// Hidden until the toolbar shortcut is pressed.
    case keybind
    /// Hidden behind a small handle on the screen edge; tap the handle to reveal it, like the iOS Dock.
    case edge

    var id: String { rawValue }
    var title: String {
        switch self {
        case .always: "Always visible while drawing"
        case .keybind: "Show and hide with a keyboard shortcut"
        case .edge: "Tap the screen edge to reveal (like the iOS Dock)"
        }
    }
}

/// How panels come and go.
enum AnimationStyle: String, CaseIterable, Identifiable, Sendable {
    case none, fade, slide, slideFade

    var id: String { rawValue }
    var slides: Bool { self == .slide || self == .slideFade }
    var fades: Bool { self == .fade || self == .slideFade }
    var title: String {
        switch self {
        case .none: "None"
        case .fade: "Fade"
        case .slide: "Slide"
        case .slideFade: "Slide and fade"
        }
    }
}
