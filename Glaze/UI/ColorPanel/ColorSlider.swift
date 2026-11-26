import SwiftUI

/// Horizontal slider over a gradient track. `value` is 0...1.
struct ColorSlider: View {
    @Binding var value: Double
    let gradient: [Color]
    var showsCheckerboard = false

    private let thumb: CGFloat = 16
    private let height: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let usable = max(geo.size.width - thumb, 1)
            ZStack(alignment: .leading) {
                if showsCheckerboard { Checkerboard().clipShape(Capsule()) }
                Capsule().fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                Capsule().strokeBorder(Color.primary.opacity(0.2))
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.35)))
                    .frame(width: thumb, height: thumb)
                    .shadow(radius: 1)
                    .offset(x: CGFloat(min(max(value, 0), 1)) * usable)
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    value = Double(min(max((g.location.x - thumb / 2) / usable, 0), 1))
                }
            )
        }
        .frame(height: height)
    }
}

private struct Checkerboard: View {
    var body: some View {
        SwiftUI.Canvas { ctx, size in
            let cell: CGFloat = 5
            for row in 0..<Int(ceil(size.height / cell)) {
                for col in 0..<Int(ceil(size.width / cell)) where (row + col) % 2 == 0 {
                    ctx.fill(Path(CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell)),
                             with: .color(.gray.opacity(0.4)))
                }
            }
        }
    }
}
