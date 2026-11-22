import AppKit

/// Dachshund silhouette for the menu bar. A template image, so macOS tints it
/// for light/dark menu bars and the highlighted state.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 24, height: 14), flipped: true) { _ in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 3, y: 4, width: 15, height: 6), xRadius: 3, yRadius: 3).fill()  // body
            NSBezierPath(ovalIn: NSRect(x: 15.5, y: 1, width: 6, height: 6)).fill()                            // head
            NSBezierPath(roundedRect: NSRect(x: 19, y: 3.5, width: 5, height: 3), xRadius: 1.5, yRadius: 1.5).fill() // snout
            for x in [4.0, 6.5, 14.0, 16.5] {                                                                    // stubby legs
                NSBezierPath(roundedRect: NSRect(x: x, y: 8.5, width: 2, height: 3.8), xRadius: 1, yRadius: 1).fill()
            }
            let tail = NSBezierPath()                                                                           // tail
            tail.move(to: NSPoint(x: 4, y: 5.5))
            tail.curve(to: NSPoint(x: 0.8, y: 2), controlPoint1: NSPoint(x: 2, y: 5.5), controlPoint2: NSPoint(x: 1, y: 4))
            tail.lineWidth = 1.6
            tail.lineCapStyle = .round
            tail.stroke()

            // Floppy ear: a thin gap around it so it reads as an ear at 14 pt.
            let ear = NSBezierPath(roundedRect: NSRect(x: 15.6, y: 2.4, width: 3, height: 6), xRadius: 1.5, yRadius: 1.5)
            NSGraphicsContext.current?.compositingOperation = .clear
            ear.lineWidth = 1.4
            ear.stroke()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            ear.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Bassotto"
        return image
    }()
}
