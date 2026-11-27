import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var preferences: Preferences
    let toolSettings: ToolSettings

    var body: some View {
        Form {
            Section("Hints") {
                Toggle("Show a hint with the name and keyboard shortcut when hovering a button", isOn: $preferences.hintsEnabled)
                LabeledSlider(title: "Delay", value: $preferences.hintDelay,
                              range: Preferences.hintDelayRange, disabled: !preferences.hintsEnabled)
            }

            Section("Laser pointer") {
                LabeledSlider(
                    title: "Trail fades after",
                    value: Binding(get: { toolSettings.laserFadeDuration },
                                   set: { toolSettings.setLaserFadeDuration($0) }),
                    range: ToolSettings.laserFadeRange)
                Text("How long the red trail stays after you stop moving the pointer.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Windows") {
                Toggle("Show the mode pill when switching between Pointer and Draw", isOn: $preferences.showModeHUD)
                Toggle("Draw over full-screen games (experimental)", isOn: $preferences.drawOverFullScreenGames)
                Text("Raises Glaze above games that take over the display. Glaze can then cover system alerts, so leave it off unless a game hides your drawings.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $preferences.automaticUpdateChecks)
            }
        }
        .formStyle(.grouped)
    }
}
