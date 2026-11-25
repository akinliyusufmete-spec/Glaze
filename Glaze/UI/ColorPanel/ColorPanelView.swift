import SwiftUI

struct ColorPanelView: View {
    @ObservedObject var model: ColorPanelModel
    var onEyedropper: () -> Void = {}

    @State private var hexText = ""
    @FocusState private var hexFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                WindowDragHandle().frame(height: 14)
                    .overlay(Image(systemName: "line.3.horizontal").font(.system(size: 9)).opacity(0.4).allowsHitTesting(false))
            }

            HSBWheel(hue: $model.hue, saturation: $model.saturation, brightness: model.brightness)
                .frame(height: 170)

            labeled("Brightness") {
                ColorSlider(value: $model.brightness, gradient: [
                    .black, Color(hue: model.hue, saturation: model.saturation, brightness: 1),
                ])
            }
            labeled("Opacity") {
                ColorSlider(value: $model.alpha, gradient: [
                    model.color.withAlpha(0).swiftUIColor, model.color.withAlpha(1).swiftUIColor,
                ], showsCheckerboard: true)
            }

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(model.color.swiftUIColor)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.25)))
                    .frame(width: 30, height: 24)

                TextField("#RRGGBB", text: $hexText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .focused($hexFocused)
                    .onSubmit(applyHex)

                Button(action: onEyedropper) { Image(systemName: "eyedropper") }
                    .help("Pick a color from the screen")
            }

            swatchRow(title: "Slots", colors: model.slots.colors, selected: model.slots.selectedIndex) { i in
                model.selectSlot(i)
            }
            if !model.recents.colors.isEmpty {
                swatchRow(title: "Recent", colors: model.recents.colors, selected: nil) { i in
                    model.apply(model.recents.colors[i])
                }
            }
        }
        .padding(12)
        .frame(width: 244)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.12)))
        .onAppear { hexText = model.color.hexString() }
        .onChange(of: model.color) { new in
            if !hexFocused { hexText = new.hexString() }
        }
    }

    private func applyHex() {
        if let c = RGBAColor(hex: hexText) {
            // Keep the current opacity unless the user typed an 8-digit value.
            let typedAlpha = hexText.filter { $0 != "#" }.count == 8 || hexText.filter { $0 != "#" }.count == 4
            model.apply(typedAlpha ? c : c.withAlpha(model.alpha))
        }
        hexText = model.color.hexString()
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary).frame(width: 62, alignment: .leading)
            content()
        }
    }

    private func swatchRow(title: String, colors: [RGBAColor], selected: Int?, tap: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary).frame(width: 46, alignment: .leading)
            ForEach(Array(colors.enumerated()), id: \.offset) { i, c in
                Button { tap(i) } label: {
                    Circle().fill(c.swiftUIColor)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.3)))
                        .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2.5).padding(-3)
                            .opacity(selected == i ? 1 : 0))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}

extension RGBAColor {
    func withAlpha(_ alpha: Double) -> RGBAColor { RGBAColor(r: r, g: g, b: b, a: alpha) }
}
