import SwiftUI

/// Hue/saturation disc. Brightness is applied as a black overlay so the wheel previews
/// the final color; the brightness itself is edited with a separate `ColorSlider`.
struct HSBWheel: View {
    @Binding var hue: Double
    @Binding var saturation: Double
    let brightness: Double

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = side / 2 - 6

            ZStack {
                Circle()
                    .fill(AngularGradient(
                        colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12).map {
                            Color(hue: $0, saturation: 1, brightness: 1)
                        },
                        center: .center))
                Circle()
                    .fill(RadialGradient(colors: [.white, .white.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: radius))
                Circle().fill(Color.black.opacity(1 - min(max(brightness, 0), 1)))
            }
            .frame(width: radius * 2, height: radius * 2)
            .position(center)
            .overlay(
                Circle()
                    .strokeBorder(Color.white, lineWidth: 2)
                    .background(Circle().strokeBorder(Color.black.opacity(0.4), lineWidth: 3.5))
                    .frame(width: 14, height: 14)
                    .position(ColorWheelMath.point(hue: hue, saturation: saturation,
                                                   center: center, radius: radius))
                    .allowsHitTesting(false)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    let r = ColorWheelMath.hueSaturation(at: g.location, center: center, radius: radius)
                    hue = r.hue
                    saturation = r.saturation
                }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
