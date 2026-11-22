# Bassotto

A dachshund who lives on your Mac. He walks along the Dock, naps on your windows,
reminds you to take breaks, and goes quiet when you're on a call.

> Early work in progress.

## Principles

- **Native only.** Swift, SwiftUI and AppKit, plus Apple frameworks. No third-party dependencies.
- **Light.** Drawn in code, pre-rendered into loops that Core Animation plays. About 0% CPU, even while he sprints.
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
  Stage/                 the strip above the Dock and the dog's behaviour
  Dog/                   line-art renderer (DogArt), sprite loops, layer view, menu bar icon
  System/                launch at login
Sources/BassottoWidget/  WidgetKit extension
Support/                 Info.plists and entitlements
scripts/AppIcon.swift    renders the app icon (make icon)
scripts/bundle.sh        builds, bundles and signs the .app (Apple Development cert if present, else ad-hoc)
```

## License

MIT. See [LICENSE](LICENSE).
