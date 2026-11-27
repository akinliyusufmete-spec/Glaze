import SwiftUI

struct AnimationSettingsView: View {
    @Bindable var preferences: Preferences
    var preview: () -> Void

    var body: some View {
        Form {
            Section("Animation") {
                Picker("Style", selection: $preferences.animationStyle) {
                    ForEach(AnimationStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.radioGroup)

                LabeledSlider(title: "Duration", value: $preferences.animationDuration,
                              range: Preferences.animationDurationRange, step: 0.01,
                              disabled: preferences.animationStyle == .none)

                HStack {
                    Button("Preview", action: preview)
                    Text("Hides and shows the toolbar with the current settings.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Slide moves the toolbar in from its screen edge. Fade also applies to the color panel and the notepad.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
