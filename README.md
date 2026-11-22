# Bassotto

A dachshund who lives on your Mac. He waddles around your screen, has the zoomies,
steals your cursor now and then, and naps when you step away.

> Early work in progress.

## Principles

- **Native only.** Swift, SwiftUI and AppKit, plus Apple frameworks. No third-party dependencies.
- **Light.** A handful of shapes, updated per frame and drawn by Core Animation. About 2% CPU while he runs around, 0% at rest, ~20 MB.
- **Private.** Everything he notices stays on your Mac.
- **No Xcode required.** Builds with the Command Line Tools and Swift Package Manager.

## Build

Requirements: macOS 14+ and the Command Line Tools (`xcode-select --install`).

```sh
make run     # build, install to /Applications, register the widget, launch
make build   # build only, into build/Bassotto.app
make clean
```

Add the widget: right-click the desktop → **Edit Widgets** → search "Bassotto".

## Make it personal

Copy `Personal.example.json` to `Personal/Personal.json` and fill it in.
The `Personal/` folder is gitignored, so your content is never committed.

## Layout

```
Sources/Bassotto/        menu bar app
  Stage/                 full-screen transparent stage and frame loop
  Dog/                   Doxie (the drawing), Brain (goose-style physics, legs, behaviours), layer view
  System/                launch at login
Sources/BassottoWidget/  WidgetKit extension
Support/                 Info.plists and entitlements
scripts/AppIcon.swift    renders the app icon (make icon)
scripts/bundle.sh        builds, bundles and signs the .app (Apple Development cert if present, else ad-hoc)
```

## License

MIT. See [LICENSE](LICENSE).
