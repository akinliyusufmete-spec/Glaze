import SwiftUI

@main
struct GlazeApp: App {
    // The one allowed singleton-like object: created here, passed down explicitly.
    @State private var environment = AppEnvironment()

    var body: some Scene {
        MenuBarExtra("Glaze", systemImage: "pencil.tip") {
            Button("Quit Glaze") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
