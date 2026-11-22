# Bassotto

A dachshund who lives on your Mac. He rests on your Dock while you work, goes for a
waddle around the screen when you step away, and hurries back the moment you return.

> Early work in progress.

## Principles

- **Native only.** Swift, SwiftUI and AppKit, plus Apple frameworks. No third-party dependencies.
- **Light.** A handful of shapes drawn by Core Animation. About 0.1% CPU while he rests, a couple of percent while he walks, ~25 MB.
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
  Dog/                   Doxie (the drawing), Brain (rest / walk / sleep from your idle time), layer view
  System/                launch at login
Sources/BassottoWidget/  WidgetKit extension
Support/                 Info.plists and entitlements
scripts/AppIcon.swift    renders the app icon (make icon)
scripts/bundle.sh        builds, bundles and signs the .app (Apple Development cert if present, else ad-hoc)
```

## License

MIT. See [LICENSE](LICENSE).
