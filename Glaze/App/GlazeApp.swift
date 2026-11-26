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
        Toggle("Show Toolbar", isOn: Binding(
            get: { environment.preferences.showToolbar },
            set: { _ in environment.toggleToolbar() }
        ))
        Button("Color Panel") { environment.toggleColorPanel() }
        Button("Pick Color from Screen") { environment.pickColorFromScreen() }
        Button("Brush Smaller") { environment.stepBrushSize(up: false) }
        Button("Brush Larger") { environment.stepBrushSize(up: true) }
        Divider()
        Button("Undo") { environment.undo() }
        Button("Redo") { environment.redo() }
        Button("Clear This Display") { environment.clearCurrentDisplay() }
        Button("Clear All Displays") { environment.clearAllDisplays() }
        Divider()
        updateItems
        Divider()
        Button("Quit Glaze") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder private var updateItems: some View {
        let checker = environment.updateChecker
        Text("Glaze \(checker.currentVersion.description)")
        switch checker.state {
        case let .available(release):
            Button("Download Glaze \(release.version.description)…") {
                NSWorkspace.shared.open(release.downloadURL ?? release.pageURL)
            }
            Button("What's New…") { NSWorkspace.shared.open(release.pageURL) }
        case .checking:
            Text("Checking for updates…")
        case .upToDate:
            Text("You're up to date")
        case let .failed(message):
            Text("Update check failed: \(message)")
        case .idle:
            EmptyView()
        }
        Button("Check for Updates…") { Task { await checker.check() } }
        Toggle("Check for Updates Automatically", isOn: Bindable(environment.preferences).automaticUpdateChecks)
    }
}
