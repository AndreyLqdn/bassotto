import AppKit

/// His resting face, line only, for the menu bar. A template image, so macOS tints it
/// for light and dark menu bars and the highlighted state.
@MainActor
enum MenuBarIcon {
    static let image: NSImage = {
        let size = NSSize(width: 24, height: 18)
        let image = NSImage(size: size, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let clear = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0)
            let black = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
            let lines = Doxie.Palette(coat: clear, ear: clear, feet: clear, outline: black, ink: black, shadow: clear)
            // Just the head: clip away the long back that stretches out behind him.
            ctx.clip(to: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            Doxie.draw(ctx, .rest(blink: false, breath: 0), at: CGPoint(x: 12, y: 16.5), scale: 0.27, palette: lines)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Bassotto"
        return image
    }()
}
