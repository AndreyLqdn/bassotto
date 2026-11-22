import AppKit

/// The dog's silhouette for the menu bar. A template image, so macOS tints it
/// for light and dark menu bars and the highlighted state.
@MainActor
enum MenuBarIcon {
    static let image: NSImage = {
        let size = NSSize(width: 26, height: 18)
        let image = NSImage(size: size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            // Draw the full-size dog side-on, then scale it into the menu bar slot.
            ctx.scaleBy(x: 0.29, y: 0.29)
            let pos = CGPoint(x: 42, y: 52)
            let pose = Doxie.Pose(pos: pos, heading: 0,
                                  feet: (0..<4).map { Doxie.restingFoot($0, pos: pos, heading: 0) })
            Doxie.draw(ctx, pose, palette: .silhouette)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Bassotto"
        return image
    }()
}
