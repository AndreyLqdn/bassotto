// swift-tools-version: 6.0
import PackageDescription

// Bassotto: a dachshund who lives on your Mac.
// Built with the Command Line Tools only (no Xcode). See scripts/bundle.sh.
let package = Package(
    name: "Bassotto",
    platforms: [.macOS(.v14)],
    targets: [
        // The menu bar app that hosts the dog.
        .executableTarget(
            name: "Bassotto",
            path: "Sources/Bassotto"
        ),
        // The WidgetKit extension. Packaged into Bassotto.app/Contents/PlugIns by bundle.sh.
        .executableTarget(
            name: "BassottoWidget",
            path: "Sources/BassottoWidget",
            swiftSettings: [.unsafeFlags(["-application-extension"])],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-application_extension"])]
        ),
    ]
)
