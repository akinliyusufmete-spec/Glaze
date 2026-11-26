import SwiftUI

struct ColorPanelView: View {
    @Bindable var model: ColorPanelModel
    var onEyedropper: () -> Void = {}
    /// Called after the hex field is submitted, so the panel can release the keyboard.
    var onFinishedTyping: () -> Void = {}

    @State private var hexText = ""
    @FocusState private var hexFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            WindowDragHandle().frame(height: 14)
                .overlay(Image(systemName: "line.3.horizontal").font(.system(size: 9)).opacity(0.4).allowsHitTesting(false))

            strokeFillRow

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
                TextField("#RRGGBB", text: $hexText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .focused($hexFocused)
                    .onSubmit(applyHex)

                Button(action: onEyedropper) { Image(systemName: "eyedropper") }
                    .help("Pick a color from the screen (C)")
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
        .frame(width: 252)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.12)))
        .onAppear { hexText = model.color.hexString() }
        .onChange(of: model.color) { _, new in
            if !hexFocused { hexText = new.hexString() }
        }
    }

    /// Two swatches choose what the wheel edits; ⇄ swaps them.
    private var strokeFillRow: some View {
        HStack(spacing: 8) {
            targetButton("Stroke", color: model.settings.strokeColor, isOn: model.target == .stroke) {
                model.target = .stroke
            }
            Button { model.swapStrokeAndFill() } label: { Image(systemName: "arrow.left.arrow.right") }
                .buttonStyle(.plain)
                .help("Swap stroke and fill")
            targetButton("Fill", color: model.settings.fillColor, isOn: model.target == .fill) {
                model.target = .fill
            }
        }
    }

    private func targetButton(_ title: String, color: RGBAColor, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 5).fill(color.swiftUIColor)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.3)))
                    .frame(width: 22, height: 18)
                Text(title).font(.caption)
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(isOn ? Color.accentColor.opacity(0.28) : .clear))
        }
        .buttonStyle(.plain)
    }

    private func applyHex() {
        let digits = hexText.filter { $0 != "#" }.count
        if let c = RGBAColor(hex: hexText) {
            // Keep the current opacity unless the user typed one (4 or 8 digits).
            model.apply(digits == 4 || digits == 8 ? c : c.withAlpha(CGFloat(model.alpha)))
            model.commit()
        }
        hexText = model.color.hexString()
        hexFocused = false
        onFinishedTyping()
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary).frame(width: 62, alignment: .leading)
            content()
        }
    }

    private func swatchRow(title: String, colors: [RGBAColor], selected: Int?, tap: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(20), spacing: 6), count: 9), alignment: .leading, spacing: 6) {
                ForEach(Array(colors.enumerated()), id: \.offset) { i, c in
                    Button { tap(i) } label: {
                        Circle().fill(c.swiftUIColor)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.3)))
                            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2.5).padding(-3)
                                .opacity(selected == i ? 1 : 0))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help(selected != nil ? "Slot \(i + 1)" : c.hexString())
                }
            }
        }
    }
}
