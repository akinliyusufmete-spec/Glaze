import KeyboardShortcuts
import SwiftUI

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            section("Anywhere", scope: .global,
                    note: "These work in every app, so keep a modifier key (⌘ ⌥ ⌃) in them. A plain letter would stop you typing it.")
            section("While drawing", scope: .drawing,
                    note: "Only active in Draw mode, so plain keys are fine. Tools with no key can be given one here.")
            Section {
                Button("Reset all shortcuts to defaults") { ShortcutCatalog.resetAll() }
            }
        }
        .formStyle(.grouped)
    }

    private func section(_ title: String, scope: ShortcutAction.Scope, note: String) -> some View {
        Section {
            ForEach(ShortcutCatalog.actions(in: scope)) { action in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(action.title)
                        Text(action.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    KeyboardShortcuts.Recorder(for: action.name)
                    Button("Reset") { KeyboardShortcuts.reset(action.name) }
                        .buttonStyle(.borderless)
                        .help("Back to the default")
                }
            }
        } header: {
            Text(title)
        } footer: {
            Text(note)
        }
    }
}
