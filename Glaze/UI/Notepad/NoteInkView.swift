import AppKit
import SwiftUI

/// Ink over the text: the same `CanvasView` the full-screen overlay uses, so pens, colors, sizes
/// and the eraser behave exactly as they do on screen. It ignores the mouse unless a drawing tool
/// is chosen, so clicks fall through to the text underneath.
struct NoteInkView: NSViewRepresentable {
    let store: CanvasStore
    let registry: ToolRegistry
    /// The drawing tool, or `nil` in Type mode.
    let tool: ToolID?

    func makeNSView(context: Context) -> CanvasView {
        let view = CanvasView(frame: .zero, displayID: NotepadModel.inkDisplayID, store: store, registry: registry)
        view.passesThroughWhenIdle = true
        return view
    }

    func updateNSView(_ view: CanvasView, context: Context) {
        if let tool { view.toolID = tool }
        view.isCapturing = tool != nil
    }
}
