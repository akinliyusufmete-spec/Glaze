import CoreGraphics

/// Decides where a floating panel (e.g. the color panel) goes relative to an anchor
/// (e.g. the toolbar). All rects use AppKit screen coordinates (origin bottom-left, y up).
enum PanelPlacement {
    enum Side: CaseIterable {
        case left, right, above, below

        var opposite: Side {
            switch self {
            case .left: return .right
            case .right: return .left
            case .above: return .below
            case .below: return .above
            }
        }
    }

    /// Returns the panel frame next to `anchor`, kept inside `visible`.
    /// Tries `preferred`, then its opposite, then the other two sides; the first side with
    /// room along its main axis wins. If none fits, `preferred` is used and clamped.
    static func frame(
        panelSize: CGSize,
        anchor: CGRect,
        visible: CGRect,
        preferred: Side = .right,
        gap: CGFloat = 8
    ) -> CGRect {
        let others = Side.allCases.filter { $0 != preferred && $0 != preferred.opposite }
        let order = [preferred, preferred.opposite] + others

        let side = order.first { fits($0, panelSize, anchor, visible, gap) } ?? preferred
        return clamp(origin(side, panelSize, anchor, gap), size: panelSize, into: visible)
    }

    private static func origin(_ side: Side, _ size: CGSize, _ anchor: CGRect, _ gap: CGFloat) -> CGPoint {
        switch side {
        case .right: return CGPoint(x: anchor.maxX + gap, y: anchor.maxY - size.height)   // tops aligned
        case .left: return CGPoint(x: anchor.minX - gap - size.width, y: anchor.maxY - size.height)
        case .below: return CGPoint(x: anchor.minX, y: anchor.minY - gap - size.height)   // left edges aligned
        case .above: return CGPoint(x: anchor.minX, y: anchor.maxY + gap)
        }
    }

    private static func fits(_ side: Side, _ size: CGSize, _ anchor: CGRect, _ visible: CGRect, _ gap: CGFloat) -> Bool {
        let o = origin(side, size, anchor, gap)
        switch side {
        case .right: return o.x + size.width <= visible.maxX
        case .left: return o.x >= visible.minX
        case .above: return o.y + size.height <= visible.maxY
        case .below: return o.y >= visible.minY
        }
    }

    private static func clamp(_ origin: CGPoint, size: CGSize, into visible: CGRect) -> CGRect {
        var x = max(visible.minX, min(origin.x, visible.maxX - size.width))
        var y = max(visible.minY, min(origin.y, visible.maxY - size.height))
        // Oversized panel: keep its leading edge and top visible.
        if size.width > visible.width { x = visible.minX }
        if size.height > visible.height { y = visible.maxY - size.height }
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}
