import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: Preferences
    let toolSettings: ToolSettings
    var resetToolbarPosition: () -> Void = {}
    var previewAnimation: () -> Void = {}

    var body: some View {
        TabView {
            GeneralSettingsView(preferences: preferences, toolSettings: toolSettings)
                .tabItem { Label("General", systemImage: "gearshape") }
            ToolbarSettingsView(preferences: preferences, resetPosition: resetToolbarPosition)
                .tabItem { Label("Toolbar", systemImage: "dock.rectangle") }
            AnimationSettingsView(preferences: preferences, preview: previewAnimation)
                .tabItem { Label("Animation", systemImage: "wand.and.rays") }
            ShortcutsSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(minWidth: 620, minHeight: 520)
    }
}

/// A slider with its current value shown beside it.
struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0.05
    var unit = "s"
    var disabled = false

    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: range, step: step)
            Text(String(format: "%.2f %@", value, unit))
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
        .disabled(disabled)
    }
}
