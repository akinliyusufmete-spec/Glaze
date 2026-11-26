import KeyboardShortcuts
import SwiftUI

struct ToolbarSettingsView: View {
    @Bindable var preferences: Preferences
    var resetPosition: () -> Void

    var body: some View {
        Form {
            Section("Where the toolbar sits") {
                Picker("Position", selection: $preferences.toolbarPlacement) {
                    ForEach(ToolbarPlacement.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.radioGroup)
                if preferences.toolbarPlacement == .floating {
                    Button("Reset floating position", action: resetPosition)
                }
                Text("Docked toolbars sit against that edge of the screen. The brush size slider and the buttons turn vertical on the left and right edges.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("How it appears") {
                Picker("Show the toolbar", selection: $preferences.toolbarReveal) {
                    ForEach(ToolbarReveal.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.radioGroup)

                switch preferences.toolbarReveal {
                case .always:
                    Toggle("Show it in Draw mode", isOn: $preferences.showToolbar)
                case .keybind:
                    HStack {
                        Text("Shortcut")
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .toggleToolbar)
                    }
                    Text("The toolbar stays hidden until you press the shortcut, and stays up until you press it again.")
                        .font(.caption).foregroundStyle(.secondary)
                case .edge:
                    LabeledSlider(title: "Hide after", value: $preferences.autoHideDelay, range: Preferences.autoHideRange)
                    Text("In Draw mode a small handle sits on the screen edge. Tap it to bring the toolbar out; it tucks away again after the pointer has stayed off it for this long.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text("Shortcut to show or hide")
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .toggleToolbar)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
