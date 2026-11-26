import CoreGraphics

/// Where the docked toolbar and its edge handle go. Pure, in AppKit screen coordinates
/// (origin bottom-left, y up). `visible` is the screen's usable area (below the menu bar).
enum DockGeometry {
    static let margin: CGFloat = 12
    static let handleLength: CGFloat = 72
    static let handleThickness: CGFloat = 10

    /// The toolbar's frame while shown: against `edge`, `margin` away from it, centred along it.
    static func shownFrame(size: CGSize, edge: DockEdge, in visible: CGRect) -> CGRect {
        var origin: CGPoint
        switch edge {
        case .top: origin = CGPoint(x: visible.midX - size.width / 2, y: visible.maxY - margin - size.height)
        case .bottom: origin = CGPoint(x: visible.midX - size.width / 2, y: visible.minY + margin)
        case .left: origin = CGPoint(x: visible.minX + margin, y: visible.midY - size.height / 2)
        case .right: origin = CGPoint(x: visible.maxX - margin - size.width, y: visible.midY - size.height / 2)
        }
        origin.x = max(visible.minX, min(origin.x, visible.maxX - size.width))
        origin.y = max(visible.minY, min(origin.y, visible.maxY - size.height))
        return CGRect(origin: origin, size: size)
    }

    /// The same frame pushed out past its edge: where a slide animation starts or ends.
    static func hiddenFrame(from shown: CGRect, edge: DockEdge) -> CGRect {
        let push = margin + 8
        switch edge {
        case .top: return shown.offsetBy(dx: 0, dy: shown.height + push)
        case .bottom: return shown.offsetBy(dx: 0, dy: -(shown.height + push))
        case .left: return shown.offsetBy(dx: -(shown.width + push), dy: 0)
        case .right: return shown.offsetBy(dx: shown.width + push, dy: 0)
        }
    }

    /// The thin tab you tap to reveal the toolbar: flush against `edge`, centred along it.
    static func handleFrame(edge: DockEdge, in visible: CGRect) -> CGRect {
        let long = handleLength, thin = handleThickness
        switch edge {
        case .top: return CGRect(x: visible.midX - long / 2, y: visible.maxY - thin, width: long, height: thin)
        case .bottom: return CGRect(x: visible.midX - long / 2, y: visible.minY, width: long, height: thin)
        case .left: return CGRect(x: visible.minX, y: visible.midY - long / 2, width: thin, height: long)
        case .right: return CGRect(x: visible.maxX - thin, y: visible.midY - long / 2, width: thin, height: long)
        }
    }

    /// Which side of the toolbar a panel attached to it (the color panel) opens on.
    static func attachedSide(for placement: ToolbarPlacement) -> PanelPlacement.Side {
        switch placement.edge {
        case .top, .none: .below
        case .bottom: .above
        case .left: .right
        case .right: .left
        }
    }
}
