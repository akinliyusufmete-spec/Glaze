# Glaze

A macOS menu-bar app for drawing and annotating on top of your screen.

## Install

1. Go to the [latest release](https://github.com/akinliyusufmete-spec/Glaze/releases/latest) and download the `.dmg`.
2. Open it and drag **Glaze** into **Applications**, then open Glaze. It lives in the menu bar.
3. The app isn't signed with an Apple Developer ID yet, so macOS warns on first launch:
   open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to the Glaze message.

Requires macOS 14 or later.

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
