#if DEBUG
import AppKit

/// DEBUG-only remote control used to verify mode switching from a script
/// without Accessibility permission (which posting a real ⌥⌘D would need).
///
/// DECISION: commands arrive as distributed notifications named
/// `app.glaze.debug.<command>` and go through `ModeController` exactly like the
/// hotkey does. Each command logs the overlay/focus state with NSLog.
/// Compiled out of Release builds.
///
///     swift -e 'import Foundation; DistributedNotificationCenter.default()
///       .postNotificationName(.init("app.glaze.debug.toggle"), object: nil,
///       userInfo: nil, deliverImmediately: true)'
@MainActor
final class DebugCommands {
    private let environment: AppEnvironment
    private var observers: [NSObjectProtocol] = []

    init(environment: AppEnvironment) {
        self.environment = environment
        let commands: [(String, @MainActor @Sendable (AppEnvironment) -> Void)] = [
            ("toggle", { $0.modeController.toggle() }),
            ("pointer", { $0.modeController.exitToPointer() }),
            ("draw", { $0.modeController.select(tool: .pen) }),
            ("status", { _ in }),
        ]
        for (name, action) in commands {
            let observer = DistributedNotificationCenter.default().addObserver(
                forName: .init("app.glaze.debug.\(name)"), object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    action(self.environment)
                    // Let AppKit settle (window ordering, activation) before reporting.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        MainActor.assumeIsolated { self.report(after: name) }
                    }
                }
            }
            observers.append(observer)
        }
        report(after: "launch")
    }

    private func report(after command: String) {
        let front = NSWorkspace.shared.frontmostApplication
        var lines = [
            "GLAZE-DEBUG [\(command)] mode=\(environment.modeController.mode.displayName)"
                + " appActive=\(NSApp.isActive)"
                + " front=\(front?.localizedName ?? "nil")(\(front?.processIdentifier ?? 0))"
                + " keyWindow=\(NSApp.keyWindow.map { String(describing: type(of: $0)) } ?? "nil")",
        ]
        let windows = environment.overlays?.windows ?? [:]
        for (id, window) in windows.sorted(by: { $0.key < $1.key }) {
            lines.append(
                "GLAZE-DEBUG   display=\(id) frame=\(NSStringFromRect(window.frame))"
                    + " level=\(window.level.rawValue) visible=\(window.isVisible)"
                    + " onActiveSpace=\(window.isOnActiveSpace)"
                    + " ignoresMouse=\(window.ignoresMouseEvents) isKey=\(window.isKeyWindow)"
                    + " capturing=\(window.canvas.isCapturing)"
            )
        }
        lines.forEach { NSLog("%@", $0) }
    }
}
#endif
