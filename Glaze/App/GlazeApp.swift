import SwiftUI

@main
struct GlazeApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(environment: environment)
        } label: {
            Image(systemName: environment.modeController.mode.capturesInput ? "pencil.tip" : "cursorarrow")
        }
    }
}

private struct MenuContent: View {
    @Bindable var environment: AppEnvironment

    private var mode: AppMode { environment.modeController.mode }

    var body: some View {
        Text("Mode: \(mode.displayName)")
        Button(mode.capturesInput ? "Switch to Pointer" : "Switch to Draw") {
            environment.modeController.toggle()
        }
        Divider()
        Toggle("Show Mode HUD", isOn: Bindable(environment.preferences).showModeHUD)
        Divider()
        Button("Undo") { environment.undo() }
        Button("Redo") { environment.redo() }
        Button("Clear This Display") { environment.clearCurrentDisplay() }
        Button("Clear All Displays") { environment.clearAllDisplays() }
        Divider()
        Button("Quit Glaze") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
