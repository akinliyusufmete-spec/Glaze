# Phase 4 — rebuilt UI + palette (integration notes)

This branch was rebuilt from a handoff summary **without access to the Phase 1–3 sources**
(they were never pushed) and **has never been compiled** — no Swift toolchain was available.
Verified so far: every file parses (tree-sitter), and the Core algorithms pass the same
assertions as the unit tests when ported to Python. Nothing has been built, run or tested in Xcode.

## Assumptions to check against the real code

- `RGBAColor` is `struct { var r, g, b, a: Double }` (0...1), `Equatable` + `Codable`, with
  memberwise `init(r:g:b:a:)`. If not, adjust `RGBAColor+Hex`, `RGBAColor+HSB`, `RGBAColor+SwiftUI`
  and `ColorPanelView` (`withAlpha`).
- Test target module is named `Glaze`. Add `GlazeTests/**` and `Glaze/**` to the right Xcode targets.
- If an `RGBAColor.withAlpha` already exists, delete the one at the bottom of `ColorPanelView.swift`.

## Not done (needs the real files)

1. **`ToolSettings.pickFill(_:)`** — add a method that sets the fill color/slot from a picked
   color, mirroring how stroke color is set; call `colorPanel.model.apply(_:)` when settings change externally.
2. **`AppEnvironment`** — create `ToolbarState`, `ToolbarController`, `ColorPanelModel`,
   `ColorPanelController`. Suggested wiring:
   - `ToolbarActions.selectTool` → tool registry; `.perform` → undo/redo/clear; `.toggleColorPanel`
     → `colorPanel.toggle(anchor: toolbar.frame)`.
   - `colorPanel.model.onColorChange = { toolSettings.pickFill($0); toolbarState.color = $0 }`.
   - Attach order: toolbar first (the color panel anchors to its frame), then show.
   - Hide both panels when the overlay hides; move the color panel with the toolbar (observe
     `NSWindow.didMoveNotification` on `toolbar.window` and call `show(anchor:)` if visible).
3. **`GlazeApp` / `DebugCommands` menus** — items for Show/Hide Toolbar, Toggle Color Panel,
   Size Up/Down (`SizeStepper.increased/decreased`), Next/Previous Color Slot (`ColorSlots`).
4. **Hotkeys** — bind `[`/`]` to `SizeStepper` and number keys to `ColorSlots.select`.

## Unverified runtime behavior (check on a Mac)

- SwiftUI buttons respond on a first click in the borderless non-activating `ToolbarPanel`.
- `WindowDragHandle` → `performDrag` moves the panel without activating the app.
- Typing in the hex field works (`ColorPanelWindow` can become key) and key status returns to the
  previous window on hide / after the eyedropper.
- `NSColorSampler` can sample other apps' pixels (needs Screen Recording permission on recent macOS).
- Panel placement across multiple screens and Spaces.
