# Glaze — Draw on your Mac's screen, then get out of the way

> **For Claude Code:** This is the full product and architecture spec. Read all of it before writing code. Build in the phase order under **Build Plan**, and at the end of each phase make sure the acceptance checks pass before starting the next. Prefer small, composable types over big view controllers. When this spec doesn't cover something, pick the most idiomatic modern AppKit/SwiftUI approach and leave a `// DECISION:` comment explaining why.

---

## 1. Concept

Glaze is a menu-bar app that puts a transparent sheet of "glass" over every display. One keybind switches between two states:

- **Draw:** the glass catches the mouse or pen, so you can annotate anything on screen.
- **Pointer:** the glass lets every click through to the apps underneath. Your drawings stay visible, but they act as if they're painted on the monitor.

Switching has to be instant (under 16 ms, no flicker, no window reordering) and must not steal focus from the app you're presenting. That one requirement drives most of the architecture.

Primary users: people giving presentations, teaching, recording tutorials, doing code reviews over screen share, or streaming.

---

## 2. Feature list

| # | Feature | Notes |
|---|---------|-------|
| F1 | **Mode toggle keybind** | Global hotkey flips Draw ↔ Pointer. Optional *hold-to-draw*: drawing works only while the key is held. |
| F2 | **Normal Pointer mode** | Overlay stays visible and passes all clicks through. Drawings persist. |
| F3 | **Drawing** | Smooth, pressure-aware strokes with mouse, trackpad or tablet. |
| F4 | **Brush variety** | Pen, Marker, Highlighter, Pencil, Calligraphy, Neon, Dashed, Eraser. |
| F5 | **Color panel** | Floating palette: swatches, recent colors, HSB picker, opacity, and an **eyedropper that samples any pixel on screen**. |
| F6 | **Shapes** | Rectangle, rounded rectangle, ellipse, line, triangle, polygon, star. Can be filled or outlined. Hold Shift for squares, circles and 45° angles. |
| F7 | **Arrows** | Straight, curved (drag the midpoint handle), elbow, double-headed. Head styles: open, filled, dot, bar. |
| F8 | **Laser brush** | Glowing stroke that fades out about 0.8 s after it's drawn. Never saved to the document. |
| F9 | **Images** | Insert from file (open panel), drag and drop from Finder, or paste. Move, scale, rotate and delete. |
| F10 | **Undo / redo / clear** | Per display. Clearing is undoable too. |
| F11 | **Export** | Save the annotation layer as a transparent PNG, or as a composited screenshot (needs Screen Recording permission, so this is opt-in). |

Nice to have, after v1: text tool, spotlight/dim mode, click-ripple visualizer, a presenter mode that auto-clears on slide change, and iCloud-synced palettes.

---

## 3. Interaction design

### 3.1 Modes (state machine)

```
            toggle key / menu
   ┌──────────────┐  ◄────────►  ┌──────────────┐
   │   POINTER    │              │     DRAW     │
   │ click-through│              │ captures input│
   └──────┬───────┘              └──────┬───────┘
          │ hold key down               │ laser key
          ▼                             ▼
   ┌──────────────┐              ┌──────────────┐
   │ MOMENTARY    │              │    LASER     │ (a Draw sub-mode:
   │ DRAW (held)  │              │  fading ink  │  same input path,
   └──────────────┘              └──────────────┘  different sink)
          │ key up → back to POINTER
```

- `AppMode` is a single enum: `.pointer`, `.draw(tool: ToolID)`, `.momentaryDraw(returnTo: AppMode)`.
- Every mode change goes through `ModeController.transition(to:)`. That's the only place where `ignoresMouseEvents`, the cursor and the HUD change.
- A small **mode HUD** (a pill in a screen corner, 1.2 s fade) shows the new mode on every change. It can be turned off.
- When in Draw mode, the cursor becomes a brush-size ring tinted with the current color.

### 3.2 Default keybinds (all rebindable in Settings)

| Action | Default | Scope |
|---|---|---|
| Toggle Draw ↔ Pointer | `⌥⌘D` | Global |
| Hold to draw (momentary) | `⌥⌘` + hold `Space`, *optional* | Global (needs Accessibility) |
| Laser brush | `⌥⌘L` | Global |
| Clear current display | `⌥⌘K` | Global |
| Hide/show all drawings | `⌥⌘H` | Global |
| Undo / Redo | `⌘Z` / `⇧⌘Z` | Draw mode |
| Tool quick keys | `P` pen, `M` marker, `H` highlighter, `E` eraser, `R` rect, `O` ellipse, `A` arrow, `L` line, `I` image, `X` laser | Draw mode |
| Brush size | `[` / `]`, or scroll while holding `⌥` | Draw mode |
| Color slots 1–9 | `1`…`9` | Draw mode |
| Eyedropper | `C` | Draw mode |
| Exit to Pointer | `Esc` | Draw mode |

Rule: global hotkeys only use modifier combos. Single-letter keys work only while Glaze has input in Draw mode, so they never hijack typing in other apps.

### 3.3 Toolbar

A floating, draggable toolbar (an `NSPanel` hosting SwiftUI) that shows up in Draw mode and auto-hides in Pointer mode. It can be pinned so it stays visible.

```
[ ✋ | ✏️ 🖍 🖊 ✒️ ⚡ | ▭ ◯ △ ★ ╱ ➜ | 🖼 | 🔴 laser | ● color | ━ size | ↶ ↷ 🗑 ]
```

Layouts: horizontal, vertical, or compact (shows the current tool only and expands on hover).

---

## 4. Technical architecture

### 4.1 Stack

- **Swift 5.10+, macOS 14+** (for `NSView.displayLink`, Observation, and modern SwiftUI).
- **AppKit** for the overlay windows, input and rendering (precise control).
- **SwiftUI** for the toolbar, color panel and Settings.
- **Swift Package Manager** for dependencies. Only one: [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) for rebindable global hotkeys (it uses Carbon `RegisterEventHotKey`, so no Accessibility permission is needed).
- An Xcode project generated by **XcodeGen** (`project.yml`), so the project file can be diffed and Claude Code can regenerate it.
- `LSUIElement = YES`: a menu-bar app with no Dock icon.

### 4.2 The overlay: how fast switching works

One `OverlayWindow` per `NSScreen`:

```swift
final class OverlayWindow: NSPanel {
    // styleMask: [.borderless, .nonactivatingPanel]
    // level: .screenSaver (above full-screen apps, below system alerts)
    // collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    // isOpaque = false, backgroundColor = .clear, hasShadow = false
    // becomesKeyOnlyIfNeeded = true
}
```

**Switching is one property flip.** Pointer mode sets `window.ignoresMouseEvents = true` and Draw mode sets it to `false`. The window is never hidden, re-created or reordered, which is why the switch doesn't flicker.

- `.nonactivatingPanel` means drawing never takes focus away from the presented app (Keynote stays in front).
- In Draw mode, the panel becomes key only when keyboard input is needed (tool shortcuts). Pressing `Esc` or going back to Pointer resigns key status and hands focus back to the previous app.
- Watch `NSApplication.didChangeScreenParametersNotification` to add or remove overlays when displays are plugged in or unplugged. Each display's drawings are kept by `CGDirectDisplayID`.

**Hold-to-draw (optional):** a `CGEventTap` (listen-only, `flagsChanged` + `keyDown/Up`) detects when the hold key goes down and comes back up. It needs Accessibility permission, so it stays off until the user turns it on in Settings, which then explains the permission and opens the right System Settings pane.

### 4.3 Module layout

```
Glaze/
├── App/
│   ├── GlazeApp.swift              // @main, menu bar extra, settings scene
│   ├── AppEnvironment.swift        // dependency container (one instance, injected)
│   └── Hotkeys.swift               // KeyboardShortcuts.Name definitions + bindings
├── Core/
│   ├── Mode/
│   │   ├── AppMode.swift
│   │   └── ModeController.swift    // the ONLY owner of mode transitions
│   ├── Document/
│   │   ├── Canvas.swift            // per-display: [Element], z-order, selection
│   │   ├── Element.swift           // protocol + concrete elements
│   │   └── CanvasStore.swift       // [DisplayID: Canvas]
│   ├── Commands/
│   │   ├── Command.swift           // protocol Command { apply / revert }
│   │   └── History.swift           // per-canvas undo/redo stacks
│   └── Geometry/
│       ├── StrokeSmoother.swift    // One-Euro filter + Catmull-Rom resampling
│       ├── ShapeGeometry.swift     // path builders for every shape
│       └── ArrowGeometry.swift     // shaft + head path builders
├── Tools/
│   ├── Tool.swift                  // protocol Tool
│   ├── ToolRegistry.swift          // ToolID -> Tool factory
│   ├── BrushTool.swift             // one tool, many BrushStyles
│   ├── ShapeTool.swift
│   ├── ArrowTool.swift
│   ├── LaserTool.swift
│   ├── ImageTool.swift
│   ├── EraserTool.swift
│   └── SelectTool.swift            // move/scale/rotate for images and shapes
├── Brushes/
│   ├── BrushStyle.swift            // value type describing a brush
│   ├── BrushPresets.swift          // the built-in brushes as data
│   └── StrokeRenderer.swift        // turns points + style into a CGPath / draw calls
├── Rendering/
│   ├── OverlayWindow.swift
│   ├── CanvasView.swift            // NSView, layer-backed
│   ├── CommittedLayer.swift        // cached bitmap of finished elements
│   ├── LiveLayer.swift             // the in-progress element, redrawn per frame
│   └── LaserLayer.swift            // CAShapeLayers with decay, display-link driven
├── UI/
│   ├── Toolbar/                    // SwiftUI toolbar in an NSPanel
│   ├── ColorPanel/                 // swatches, HSB wheel, eyedropper
│   ├── HUD/                        // mode pill
│   └── Settings/                   // hotkeys, brushes, behavior, permissions
└── Persistence/
    ├── Preferences.swift           // @AppStorage-backed settings
    └── Exporter.swift              // PNG export
```

Dependency rule: `Core` imports nothing from the other folders. `Tools` depends on `Core` and `Brushes`. `Rendering` and `UI` depend on everything below them. Nothing depends on `App`.

### 4.4 Key abstractions

```swift
// One protocol drives every tool. Adding a tool = one new type + one registry line.
protocol Tool: AnyObject {
    var id: ToolID { get }
    var cursor: NSCursor { get }
    func begin(at p: InputPoint, in ctx: ToolContext)
    func move(to p: InputPoint, in ctx: ToolContext)
    func end(at p: InputPoint, in ctx: ToolContext)    // usually emits a Command
    func cancel(in ctx: ToolContext)
    func modifiersChanged(_ flags: NSEvent.ModifierFlags, in ctx: ToolContext) // Shift-constrain etc.
}

struct InputPoint {
    var location: CGPoint
    var pressure: CGFloat      // 1.0 for mouse; NSEvent.pressure for tablet/Force Touch
    var tilt: CGPoint          // tablet tilt, used by Calligraphy
    var timestamp: TimeInterval
}

// Elements are value types; the canvas is just an ordered array of them.
protocol Element: Identifiable, Hashable {
    var id: UUID { get }
    var bounds: CGRect { get }
    var transform: CGAffineTransform { get set }
    func draw(in ctx: CGContext)
    func hitTest(_ p: CGPoint, tolerance: CGFloat) -> Bool
}
// Concrete: StrokeElement, ShapeElement, ArrowElement, ImageElement

protocol Command {
    func apply(to canvas: inout Canvas)
    func revert(on canvas: inout Canvas)
}
// AddElement, RemoveElements, TransformElement, Clear (stores the removed array)
```

**Brushes are data, not subclasses.** Every brush in F4 is a `BrushStyle` preset that the same `StrokeRenderer` reads:

```swift
struct BrushStyle: Codable, Hashable {
    var name: String
    var baseWidth: CGFloat
    var opacity: CGFloat
    var blendMode: CGBlendMode        // highlighter = .multiply
    var pressureCurve: PressureCurve  // .none, .linear, .ease(exponent)
    var taper: Taper                  // start/end taper lengths
    var nibAngle: CGFloat?            // calligraphy: width varies with stroke direction
    var dash: [CGFloat]?              // dashed brush
    var glow: Glow?                   // neon & laser: blur radius + inner core color
    var jitter: CGFloat               // pencil: tiny positional noise + grain texture
    var isTransient: Bool             // laser = true → never committed to the canvas
    var fadeDuration: TimeInterval?   // laser decay
}
```

Built-in presets:

| Brush | What makes it distinct |
|---|---|
| Pen | Thin, light pressure response, small end taper |
| Marker | Thick, flat ends, 90% opacity |
| Highlighter | Very thick, 35% opacity, `.multiply`, straightens automatically if the stroke is nearly straight |
| Pencil | Jitter + grain, strong pressure response |
| Calligraphy | Nib angle 45°, width follows stroke direction |
| Neon | Glow: bright white core + colored blur |
| Dashed | Dash pattern, round caps |
| Laser | Neon look, `isTransient`, fades over 0.8 s |

Users can duplicate and tweak presets in Settings. Custom brushes are saved as JSON.

### 4.5 Rendering pipeline (keeps 120 Hz smooth)

1. **CommittedLayer:** a cached `CGImage` of every finished element. It's redrawn only when the canvas changes (add, undo, clear, transform), never on every frame.
2. **LiveLayer:** only the in-progress stroke or shape, redrawn on each input event. A stroke being drawn is never drawn into the cache.
3. **LaserLayer:** one `CAShapeLayer` per laser segment. A display link lowers `opacity` and trims `strokeStart` over `fadeDuration`, then removes the layer. The trail fades from tail to head, which feels like a real laser pointer.
4. **Stroke smoothing:** a One-Euro filter on the raw points (cuts jitter without lag), then Catmull-Rom resampling for the final path. Coalesced events from `NSEvent` (where available) give high-rate tablet input.

Target: under 8 ms per frame at 5K with 500 committed elements. Committed elements cost nothing per frame because they're cached.

### 4.6 Color panel

- A SwiftUI `ColorPanelView` in its own non-activating `NSPanel`, attached to the toolbar's color button and detachable.
- Sections: **9 slots** (mapped to keys `1`–`9`), **recent colors** (last 12), **HSB wheel + brightness slider**, **opacity slider**, **hex field**.
- **Eyedropper:** `NSColorSampler().show { color in … }`. It samples any pixel on any display and needs no Screen Recording permission. The picked color goes into Recent automatically.
- Stroke color and fill color are separate (Fill is used by shapes). A ⇄ button swaps them.

### 4.7 Shapes and arrows

- Dragging defines the bounding box. `Shift` constrains (square, circle, 45° snap). `⌥` draws from the center.
- After placing a shape, it shows handles for **2 seconds** (or until the next action) so you can adjust it, then commits. This avoids a separate select step for quick fixes.
- Polygon: click to add points, double-click to close. Star: drag sets size, scroll while dragging changes the point count.
- Arrows: `ArrowGeometry` builds the shaft (straight, quadratic curve or elbow) and positions the head from the shaft's tangent at the end. Head size scales with stroke width but has a minimum, so thin arrows stay readable.

### 4.8 Images

- Three ways in: the toolbar button (`NSOpenPanel` limited to `UTType.image`), dropping files onto the overlay in Draw mode (`registerForDraggedTypes([.fileURL, .png, .tiff])`), and `⌘V` with image data on the clipboard.
- Images drop in centered on the cursor, scaled to fit within 50% of the screen.
- `ImageElement` stores a downsampled `CGImage` (made with `CGImageSourceCreateThumbnailAtIndex`, capped at 2× the display's backing size) to save memory.
- `SelectTool` handles moving, corner scaling (Shift keeps the aspect ratio) and rotation with the rotation handle (snaps to 15° with Shift). `Delete` removes the image.

### 4.9 Settings

Tabs: **General** (launch at login via `SMAppService`, show the HUD, toolbar auto-hide), **Shortcuts** (KeyboardShortcuts recorders), **Brushes** (edit presets, set laser fade time), **Behavior** (clear drawings when switching to Pointer: off by default; separate canvas per Space: off by default), **Permissions** (status and "Open System Settings" buttons for Accessibility and Screen Recording, with a plain-language explanation of why each is needed).

---

## 5. Permissions

| Permission | Needed for | Default |
|---|---|---|
| none | Everything in v1 except the two items below | — |
| Accessibility | Hold-to-draw (event tap) | Off; asked for only when the user turns it on |
| Screen Recording | Composited screenshot export | Off; asked for only on first use |

The app must work fully with neither permission granted.

---

## 6. Build plan (phases for Claude Code)

Each phase ends with a working, runnable app. Commit at the end of each phase.

**Phase 0: Scaffold**
- XcodeGen `project.yml`, app target, `LSUIElement`, KeyboardShortcuts via SPM, a menu bar extra with Quit.
- ✅ Check: `xcodegen && xcodebuild -scheme Glaze build` succeeds; a menu bar icon appears.

**Phase 1: Overlay + mode toggle** *(the core of the product)*
- `OverlayWindow` on every screen, `ModeController`, the `⌥⌘D` hotkey, the HUD pill, multi-display add/remove.
- A temporary hard-coded red pen to prove input works.
- ✅ Check: in Pointer mode you can click and type in apps under a drawing; in Draw mode you can draw; switching doesn't flicker or change which app is in front; works over a full-screen app and on a second display.

**Phase 2: Document, tools, undo**
- `Element`, `Canvas`, `Command`, `History`, `Tool` protocol, `ToolRegistry`, `BrushTool`, `EraserTool` (stroke eraser).
- The committed/live layer split.
- ✅ Check: 300 strokes keep drawing at full frame rate; undo/redo/clear work per display.

**Phase 3: Brushes + smoothing**
- `BrushStyle`, all presets, `StrokeRenderer`, One-Euro + Catmull-Rom, pressure and tilt.
- ✅ Check: each preset is clearly different; tablet pressure changes width; the highlighter darkens the underlying content with multiply.

**Phase 4: Toolbar + color panel**
- SwiftUI toolbar panel, tool quick keys, size control, the color panel with eyedropper, 9 slots, and recent colors.
- ✅ Check: everything can be done without a mouse; the eyedropper samples a pixel from another app's window.

**Phase 5: Laser**
- `LaserTool`, `LaserLayer` with display-link decay, the `⌥⌘L` hotkey.
- ✅ Check: laser strokes fade from tail to head in about 0.8 s, never show up in undo history, and draw smoothly at 120 Hz.

**Phase 6: Shapes + arrows**
- `ShapeTool`, `ArrowTool`, geometry builders, Shift/⌥ modifiers, the 2-second adjust handles, fill vs stroke.
- ✅ Check: every shape and arrow variant can be drawn, constrained and undone.

**Phase 7: Images + selection**
- `ImageTool`, drag-and-drop, paste, `SelectTool` transforms, downsampling.
- ✅ Check: a 50 MP photo loads without a memory spike over about 150 MB and can be moved, scaled and rotated.

**Phase 8: Settings, hold-to-draw, export, polish**
- Settings tabs, the optional event-tap momentary mode, PNG export, launch at login, an app icon.
- ✅ Check: every shortcut can be rebound; the app works with no permissions granted.

---

## 7. Code conventions

- One type per file. Files stay under about 250 lines; split them when they get bigger.
- No singletons except `AppEnvironment`, which is created in `GlazeApp` and passed down.
- Mode changes only through `ModeController`. Canvas changes only through `Command`s, so undo always works.
- Use `@MainActor` on everything that touches UI. Geometry and smoothing are pure functions with unit tests.
- Tests (XCTest): `StrokeSmoother`, `ShapeGeometry`, `ArrowGeometry`, `History` apply/revert, `ModeController` transitions.
- Leave a `// DECISION:` comment for any choice this spec doesn't cover.

---

## 8. Kickoff prompt

Paste this into Claude Code from an empty folder that contains this file:

```
Read SPEC.md fully. Then do Phase 0 and Phase 1 only. Set up XcodeGen, build
the overlay windows and ModeController, and prove that ⌥⌘D switches between
click-through and drawing on every display without flicker or stealing focus.
Run the build, fix every error, and stop when Phase 1's checks pass. Then
summarize what you built and anything you decided that the spec didn't cover.
```

After that, run one phase per prompt: "Continue with Phase N of SPEC.md."
