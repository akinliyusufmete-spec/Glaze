# Phase 4 — toolbar + color panel (status notes)

Built on top of `phases-1-3` (`0a1e4aa`). **Nothing here has been compiled or run**: it was written
in a Linux container with no Swift toolchain. What was checked: every changed file parses
(tree-sitter; the three files it flags — `StrokeGeometry`, `LiveLayer`, `BrushTool` line 92 — fail
on untouched `var final` / existing constructs, same as before this branch), and the pure
palette algorithms were cross-checked in Python against the unit-test expectations.

First steps on a Mac: `xcodegen generate`, build, run `GlazeTests`, fix whatever the compiler finds.

## What changed

- **New, `Glaze/Core/Palette` + `Core/Geometry`** (pure, unit-tested): hex parsing, HSB conversion,
  `ColorSlots` (9), `RecentColors` (12), `SizeStepper`, `ColorWheelMath`, `PanelPlacement`.
- **New, `Glaze/Tools/ToolSettings.swift`**: stroke/fill colors (`pickStroke`, `pickFill`, swap),
  slots, recents and per-brush widths, persisted in UserDefaults. `BrushTool` reads color and width
  when a stroke begins; `ToolRegistry(settings:)` builds settings-driven brushes (no-arg init keeps
  the old fixed colors, so existing tests are unchanged).
- **New, `Glaze/UI/Toolbar`, `UI/ColorPanel`, `UI/Support`**: toolbar panel, color panel (wheel,
  brightness/opacity sliders, hex field, stroke/fill targets with ⇄, slots, recents, eyedropper).
  Panels sit at `.screenSaver + 1` because the overlay windows are at `.screenSaver`.
- **Edited**: `Hotkeys` (M, H, `[`, `]`, `C`, `1`–`9`; capture-only keys are suspended while the
  color panel is key so hex typing works), `AppEnvironment` (owns settings, toolbar, panel; size,
  slot, eyedropper, toggle methods), `Preferences.showToolbar`, `GlazeApp` menu, `DebugCommands`
  (`toolbar`, `colorpanel`, `sizeup`, `sizedown`, `slot1`, `slot5`, `eyedropper`; status line now
  prints color/size/panel state).
- **Tests**: `Palette/*`, `Geometry/PanelPlacementTests`, `ToolSettingsTests`, `UI/*`.

## Decisions (also marked `DECISION:` in code)

- One stroke color for all brushes; highlighter translucency comes from its style.
- Brush sizes are per brush; the eraser has no size control yet.
- Toolbar shows in `.draw`, hides in Pointer, is left alone during momentary draw.
- Eyedropper needs no Screen Recording permission (`NSColorSampler`), per SPEC §4.6.

## Verify on a Mac (the SPEC's Phase 4 checks)

1. Toolbar buttons respond on the first click (non-activating borderless panel) and do not draw.
2. The drag handle moves both panels; the color panel follows the toolbar.
3. Typing a hex value works (panel becomes key), `Enter` applies it, then `P`/`E`/`1`–`9` work again.
4. Esc in the hex field closes the panel instead of leaving Draw mode.
5. Eyedropper (`C`) samples a pixel from another app's window; focus returns to that app.
6. Everything is reachable without the mouse: tools, size, slots, eyedropper, undo/redo/clear;
   the color panel itself is mouse/menu-only.
7. The brush cursor ring updates color/size (it refreshes on the next mouse move).
8. The overlay's cursor handling doesn't fight the toolbar when the pointer is over it.
9. Multiple displays and Spaces: panel placement and visibility.

## Known gaps

- No keyboard shortcut for the color panel itself (menu / toolbar button only).
- Toolbar undo/redo buttons are never disabled (no canvas-state observation yet).
- No Settings UI for the new shortcuts (Phase 8).
