import AppKit

/// The dog's silhouette in profile for the menu bar. A template image, so macOS tints it
/// for light and dark menu bars and the highlighted state.
@MainActor
enum MenuBarIcon {
    static let image: NSImage = {
        let size = NSSize(width: 28, height: 18)
        let image = NSImage(size: size, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let black = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
            let clear = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0)
            let silhouette = Doxie.Palette(coat: black, outline: black, ears: black, feet: black, eye: clear, shadow: clear)
            var dog = Doxie.State(pos: CGPoint(x: 13, y: 14.5), direction: 0)
            dog.wag = 0.5
            Doxie.draw(ctx, dog, scale: 0.4, palette: silhouette)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Bassotto"
        return image
    }()
}
