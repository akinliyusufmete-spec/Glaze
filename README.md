# Glaze

A macOS menu-bar app for drawing and annotating on top of your screen.

## Install

1. Go to the [latest release](https://github.com/akinliyusufmete-spec/Glaze/releases/latest) and download the `.dmg`.
2. Open it and drag **Glaze** into **Applications**, then open Glaze. It lives in the menu bar.
3. The app isn't signed with an Apple Developer ID yet, so macOS warns on first launch:
   open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to the Glaze message.

Requires macOS 14 or later.

## Notepad

Press **⌥⌘N** (or use the toolbar's notepad button or the menu) to open a floating notepad. It works
from Pointer mode — you don't have to be in Draw mode.

- **Type** mode is a plain text editor; **Pen / Marker / Highlighter / Eraser** draw ink over the text.
  Text and ink stay on the same page, so you can annotate your own notes.
- Ink uses the same colors, sizes and brushes as the screen overlay; the swatch opens the color panel.
- Several pages: previous / next, new page, delete page. Undo / redo / clear apply to the current page's ink.
- Everything is saved automatically to `~/Library/Application Support/Glaze/notebook.json` and restored on launch.
- Esc or ⌥⌘N closes it, and the keyboard goes back to the app you were in.

## Full-screen apps and games

Glaze's overlay, toolbar, color panel and notepad appear on every Space, including full-screen ones,
so they work over native full-screen apps, full-screen browser tabs and borderless-window games.

Some games take over the display exclusively and hide ordinary windows. For those, turn on
**Draw Over Full-Screen Games (experimental)** in the menu. It raises Glaze above the display shield;
as a side effect Glaze can then cover system alerts, so leave it off unless you need it.

## Updates

Glaze checks GitHub Releases once a day (turn it off in the menu: *Check for Updates Automatically*)
and shows **Download Glaze x.y.z…** in its menu when a newer version exists. *Check for Updates…* checks right away.

## Build from source

```
brew install xcodegen
xcodegen generate
open Glaze.xcodeproj
```

See `SPEC.md` for the design and `PHASE4_INTEGRATION.md` for the current status and checks.

## Releasing (maintainers)

Update nothing by hand. Either push a tag, or open Actions → Release → Run workflow and enter a version; both build, package and publish a release.

```
git tag v0.1.0
git push origin v0.1.0
```

The workflow in `.github/workflows/release.yml` takes the version from the tag, builds a Release app,
ad-hoc signs it, produces `Glaze-<version>.dmg`, `.zip` and `SHA256SUMS.txt`, and publishes them.
`.github/workflows/ci.yml` builds and tests every push and pull request.
