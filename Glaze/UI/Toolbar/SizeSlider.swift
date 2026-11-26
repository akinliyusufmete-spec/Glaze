import SwiftUI

/// Drag to change the current tool's size. Logarithmic (see `SizeScale`) with a live dot that
/// shows the size in the current color.
struct SizeSlider: View {
    let tool: ToolID?
    let settings: ToolSettings
    let vertical: Bool
    var length: CGFloat = 92

    private let thumb: CGFloat = 14
    private let preview: CGFloat = 20

    private var size: Double? { tool.flatMap { settings.effectiveWidth(for: $0) }.map(Double.init) }

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 6))
        layout {
            if vertical { track; dot } else { dot; track }
        }
        .opacity(size == nil ? 0.35 : 1)
        .hint(Hint(title: "Brush size",
                   detail: size.map { "Drag to change the size. Now \(Self.format($0)) pt. \(Self.keysLine)" }
                       ?? "This tool has no size.",
                   actionID: nil))
        .accessibilityLabel("Brush size")
    }

    private var dot: some View {
        let d = min(max(size ?? 4, 3), preview - 2)
        return ZStack {
            Circle().fill(settings.strokeColor.swiftUIColor).frame(width: d, height: d)
        }
        .frame(width: preview, height: preview)
    }

    private var track: some View {
        let usable = length - thumb
        let fraction = SizeScale.fraction(forSize: size ?? SizeScale.minimum)
        return ZStack(alignment: vertical ? .bottom : .leading) {
            Capsule().fill(Color.primary.opacity(0.2))
                .frame(width: vertical ? 4 : length, height: vertical ? length : 4)
            Circle().fill(Color.white)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.35)))
                .shadow(radius: 1)
                .frame(width: thumb, height: thumb)
                .offset(x: vertical ? 0 : CGFloat(fraction) * usable,
                        y: vertical ? -CGFloat(fraction) * usable : 0)
        }
        .frame(width: vertical ? thumb : length, height: vertical ? length : thumb)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
            guard let tool, size != nil else { return }
            let position = vertical ? length - drag.location.y : drag.location.x
            let t = min(max((position - thumb / 2) / usable, 0), 1)
            settings.setWidth(CGFloat(SizeScale.size(forFraction: Double(t))), for: tool)
        })
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    private static var keysLine: String {
        let down = ShortcutCatalog.action("sizeDown")?.shortcutText
        let up = ShortcutCatalog.action("sizeUp")?.shortcutText
        guard let down, let up else { return "" }
        return "Keys: \(down) smaller, \(up) larger."
    }
}
