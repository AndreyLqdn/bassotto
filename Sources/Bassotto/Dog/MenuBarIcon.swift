import AppKit
import SwiftUI

/// The dog's head in profile, line only, for the menu bar. A template image, so macOS
/// tints it for light and dark menu bars and the highlighted state.
@MainActor
enum MenuBarIcon {
    static let image: NSImage = {
        let size = CGSize(width: 22, height: 18)
        var palette = DogArt.Palette.classic
        palette.ink = .black
        let renderer = ImageRenderer(content:
            Canvas { ctx, canvasSize in
                DogArt.headIcon(&ctx, in: CGRect(origin: .zero, size: canvasSize).insetBy(dx: 0.5, dy: 0.5),
                                palette: palette, knockout: true)
            }
            .frame(width: size.width, height: size.height)
        )
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(systemSymbolName: "dog", accessibilityDescription: nil)!
        image.size = size
        image.isTemplate = true
        image.accessibilityDescription = "Bassotto"
        return image
    }()
}
