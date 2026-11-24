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
            ("pen", { $0.modeController.select(tool: .pen) }),
            ("eraser", { $0.modeController.select(tool: .eraser) }),
            ("marker", { $0.modeController.select(tool: .marker) }),
            ("highlighter", { $0.modeController.select(tool: .highlighter) }),
            ("pencil", { $0.modeController.select(tool: .pencil) }),
            ("calligraphy", { $0.modeController.select(tool: .calligraphy) }),
            ("neon", { $0.modeController.select(tool: .neon) }),
            ("dashed", { $0.modeController.select(tool: .dashed) }),
            ("presets", { env in
                guard let window = Self.windowUnderMouse(env) else { return }
                DebugPresets.draw(env.canvasStore, display: window.displayID, size: window.frame.size)
            }),
            ("undo", { $0.undo() }),
            ("redo", { $0.redo() }),
            ("clear", { $0.clearCurrentDisplay() }),
            ("clearall", { $0.clearAllDisplays() }),
            ("stress300", { env in
                guard let window = Self.windowUnderMouse(env) else { return }
                DebugBench.stress(env.canvasStore, display: window.displayID, size: window.frame.size)
            }),
            ("bench", { env in
                guard let window = Self.windowUnderMouse(env) else { return }
                DebugBench.run(on: window.canvas, store: env.canvasStore)
            }),
            ("snapshot", { env in
                guard let window = Self.windowUnderMouse(env) else { return }
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("glaze-\(window.displayID).png")
                let ok = window.canvas.debugSnapshot(to: url)
                NSLog("%@", "GLAZE-DEBUG [snapshot] \(ok ? url.path : "failed")")
            }),
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
        let store = environment.canvasStore
        let windows = environment.overlays?.windows ?? [:]
        for (id, window) in windows.sorted(by: { $0.key < $1.key }) {
            lines.append(
                "GLAZE-DEBUG   display=\(id) frame=\(NSStringFromRect(window.frame))"
                    + " level=\(window.level.rawValue) visible=\(window.isVisible)"
                    + " onActiveSpace=\(window.isOnActiveSpace)"
                    + " ignoresMouse=\(window.ignoresMouseEvents) isKey=\(window.isKeyWindow)"
                    + " capturing=\(window.canvas.isCapturing)"
                    + " tool=\(window.canvas.toolID)"
                    + " elements=\(store.canvas(for: id).elements.count)"
                    + " undo=\(store.undoCount(on: id)) redo=\(store.redoCount(on: id))"
            )
        }
        lines.forEach { NSLog("%@", $0) }
    }

    private static func windowUnderMouse(_ environment: AppEnvironment) -> OverlayWindow? {
        guard let id = environment.overlays?.displayUnderMouse() else { return nil }
        return environment.overlays?.windows[id]
    }
}
#endif
