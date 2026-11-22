import CoreGraphics
import Foundation

/// The dachshund: a few chunky rounded shapes with a soft outline and round little feet.
/// Everything is drawn relative to `origin`, the point on the ground (or the Dock edge)
/// under him, in y-down coordinates. Feet are always computed from the body, so nothing
/// can be left behind when he moves fast.
enum Doxie {
    struct Palette: Sendable {
        var coat = CGColor(srgbRed: 0.98, green: 0.94, blue: 0.87, alpha: 1)       // cream
        var ear = CGColor(srgbRed: 0.87, green: 0.66, blue: 0.44, alpha: 1)        // caramel
        var feet = CGColor(srgbRed: 0.87, green: 0.66, blue: 0.44, alpha: 1)
        var outline = CGColor(srgbRed: 0.46, green: 0.39, blue: 0.35, alpha: 1)    // soft warm grey
        var ink = CGColor(srgbRed: 0.18, green: 0.14, blue: 0.12, alpha: 1)
        var shadow = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.12)
        static let cream = Palette()
        static let red = Palette(coat: CGColor(srgbRed: 0.80, green: 0.50, blue: 0.27, alpha: 1),
                                 ear: CGColor(srgbRed: 0.58, green: 0.32, blue: 0.15, alpha: 1),
                                 feet: CGColor(srgbRed: 0.58, green: 0.32, blue: 0.15, alpha: 1),
                                 outline: CGColor(srgbRed: 0.36, green: 0.21, blue: 0.11, alpha: 1))
        static let silhouette: Palette = {
            let k = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
            return Palette(coat: k, ear: k, feet: k, outline: k, ink: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0),
                           shadow: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0))
        }()
    }

    enum Pose: Sendable {
        /// Side view. `phase` advances with distance travelled; `speed` 0…1 (walk → run).
        case walk(phase: CGFloat, speed: CGFloat)
        /// Front view lying on the Dock, awake. `blink` closes the eyes for a moment.
        case rest(blink: Bool, breath: CGFloat)
        /// Front view lying on the Dock, asleep.
        case sleep(breath: CGFloat)
    }

    static let outlineWidth: CGFloat = 3

    static func draw<C: DoxieCanvas>(_ canvas: inout C, _ pose: Pose, at origin: CGPoint,
                                     facingRight: Bool = true, scale: CGFloat = 1, palette: Palette = .cream) {
        var base = CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: scale * (facingRight ? 1 : -1), y: scale)
        var painter = Painter(canvas: canvas, palette: palette)
        switch pose {
        case .walk(let phase, let speed): walk(&painter, &base, phase: phase, speed: speed)
        case .rest(let blink, let breath): front(&painter, &base, asleep: false, blink: blink, breath: breath)
        case .sleep(let breath): front(&painter, &base, asleep: true, blink: false, breath: breath)
        }
        canvas = painter.canvas
    }

    static func draw(_ ctx: CGContext, _ pose: Pose, at origin: CGPoint, facingRight: Bool = true,
                     scale: CGFloat = 1, palette: Palette = .cream) {
        var canvas = ContextCanvas(ctx: ctx)
        draw(&canvas, pose, at: origin, facingRight: facingRight, scale: scale, palette: palette)
    }

    // MARK: Side view (walking)

    private static func walk<C>(_ p: inout Painter<C>, _ t: inout CGAffineTransform, phase: CGFloat, speed: CGFloat) {
        let c = p.palette
        let stride: CGFloat = 3 + speed * 3, lift: CGFloat = 3 + speed * 3
        p.fill(CGPath(ellipseIn: CGRect(x: -36, y: -4, width: 72, height: 9), transform: &t), c.shadow)

        // Round feet: diagonal pairs step together, always attached under the body.
        func foot(_ x: CGFloat, _ pair: CGFloat) -> CGPath {
            let s = sin(phase + pair * .pi)
            let fx = x + s * stride
            let fy = -5 - max(0, cos(phase + pair * .pi)) * lift
            return CGPath(ellipseIn: CGRect(x: fx - 6, y: fy - 5, width: 12, height: 10), transform: &t)
        }
        let back = [foot(-23, 1), foot(17, 0)], near = [foot(-15, 0), foot(25, 1)]
        for f in back { p.outlined(f, c.feet) }

        // Goose waddle: the whole body rocks side to side as he steps.
        let rock = sin(phase) * (0.05 + speed * 0.04)
        let bob = abs(sin(phase)) * (1.5 + speed * 2)
        var body = t.translatedBy(x: 0, y: -10 - bob).rotated(by: rock).translatedBy(x: 0, y: 10)

        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: -34, y: -28))
        tail.addQuadCurve(to: CGPoint(x: -46, y: -42 + sin(phase * 2) * 3), control: CGPoint(x: -44, y: -30))
        p.tube(tail.copy(using: &body)!, width: 7, c.coat)

        p.outlined(CGPath(roundedRect: CGRect(x: -38, y: -38, width: 70, height: 30), cornerWidth: 15, cornerHeight: 15, transform: &body), c.coat)
        p.outlined(CGPath(ellipseIn: CGRect(x: 14, y: -58, width: 34, height: 32), transform: &body), c.coat)        // head
        p.outlined(CGPath(roundedRect: CGRect(x: 36, y: -47, width: 22, height: 15), cornerWidth: 7.5, cornerHeight: 7.5, transform: &body), c.coat) // snout
        p.fill(CGPath(ellipseIn: CGRect(x: 52, y: -47, width: 9, height: 8), transform: &body), c.ink)             // nose
        p.fill(CGPath(ellipseIn: CGRect(x: 31, y: -50, width: 7, height: 7.5), transform: &body), c.ink)           // eye
        p.fill(CGPath(ellipseIn: CGRect(x: 33.6, y: -48.8, width: 2.4, height: 2.4), transform: &body), CGColor(gray: 1, alpha: 1))
        let smile = CGMutablePath()
        smile.move(to: CGPoint(x: 45, y: -35)); smile.addQuadCurve(to: CGPoint(x: 53, y: -36), control: CGPoint(x: 49, y: -32))
        p.line(smile.copy(using: &body)!, width: 2)

        // Floppy ear, swinging a beat behind the body.
        var ear = body.translatedBy(x: 22, y: -52).rotated(by: sin(phase - 1) * (0.12 + speed * 0.25) - speed * 0.3)
        p.outlined(CGPath(roundedRect: CGRect(x: -7, y: -2, width: 14, height: 26), cornerWidth: 7, cornerHeight: 7, transform: &ear), c.ear)

        for f in near { p.outlined(f, c.feet) }
    }

    // MARK: Front view (resting / sleeping on the Dock)

    private static func front<C>(_ p: inout Painter<C>, _ t: inout CGAffineTransform, asleep: Bool, blink: Bool, breath: CGFloat) {
        let c = p.palette
        let height: CGFloat = asleep ? 42 : 50
        var b = t.scaledBy(x: 1, y: 1 + breath * 0.025)                     // breathing, anchored on the Dock

        // His long back and tail stretch out behind him along the Dock.
        let back = CGMutablePath()
        back.move(to: CGPoint(x: 20, y: 0))
        back.addCurve(to: CGPoint(x: 78, y: -24), control1: CGPoint(x: 30, y: -30), control2: CGPoint(x: 60, y: -26))
        back.addCurve(to: CGPoint(x: 98, y: 0), control1: CGPoint(x: 92, y: -22), control2: CGPoint(x: 98, y: -12))
        back.closeSubpath()
        p.outlined(back.copy(using: &b)!, c.coat)
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: 94, y: -12)); tail.addQuadCurve(to: CGPoint(x: 110, y: -24), control: CGPoint(x: 108, y: -12))
        p.tube(tail.copy(using: &b)!, width: 7, c.coat)

        // Head: a round dome sitting on the Dock like a loaf.
        let dome = CGMutablePath()
        dome.move(to: CGPoint(x: -42, y: 0))
        dome.addCurve(to: CGPoint(x: 0, y: -height), control1: CGPoint(x: -44, y: -height * 0.75), control2: CGPoint(x: -26, y: -height))
        dome.addCurve(to: CGPoint(x: 42, y: 0), control1: CGPoint(x: 26, y: -height), control2: CGPoint(x: 44, y: -height * 0.75))
        dome.closeSubpath()
        p.outlined(dome.copy(using: &b)!, c.coat)

        // Floppy ears hanging down both cheeks.
        for side in [-1.0, 1.0] as [CGFloat] {
            var e = b.translatedBy(x: side * 33, y: -height + 10).rotated(by: side * (asleep ? 0.35 : 0.12))
            p.outlined(CGPath(roundedRect: CGRect(x: -7.5, y: -2, width: 15, height: 32), cornerWidth: 7.5, cornerHeight: 7.5, transform: &e), c.ear)
        }

        // Face.
        let eyeY = -height * 0.62
        for side in [-1.0, 1.0] as [CGFloat] {
            if asleep || blink {
                let lid = CGMutablePath()
                lid.move(to: CGPoint(x: side * 15 - 5, y: eyeY)); lid.addQuadCurve(to: CGPoint(x: side * 15 + 5, y: eyeY), control: CGPoint(x: side * 15, y: eyeY + 4.5))
                p.line(lid.copy(using: &b)!, width: 2.4)
            } else {
                p.fill(CGPath(ellipseIn: CGRect(x: side * 15 - 3.8, y: eyeY - 4, width: 7.6, height: 8), transform: &b), c.ink)
                p.fill(CGPath(ellipseIn: CGRect(x: side * 15 - 1.2, y: eyeY - 2.6, width: 2.6, height: 2.6), transform: &b), CGColor(gray: 1, alpha: 1))
            }
        }
        let noseY = -height * 0.42
        p.fill(CGPath(ellipseIn: CGRect(x: -6.5, y: noseY - 4.5, width: 13, height: 9.5), transform: &b), c.ink)
        let mouth = CGMutablePath()
        mouth.move(to: CGPoint(x: 0, y: noseY + 4.5)); mouth.addLine(to: CGPoint(x: 0, y: noseY + 8))
        mouth.move(to: CGPoint(x: -6, y: noseY + 8)); mouth.addQuadCurve(to: CGPoint(x: 0, y: noseY + 8), control: CGPoint(x: -3, y: noseY + 12))
        mouth.addQuadCurve(to: CGPoint(x: 6, y: noseY + 8), control: CGPoint(x: 3, y: noseY + 12))
        p.line(mouth.copy(using: &b)!, width: 2)

        // Front paws resting on the Dock edge, just over it.
        for side in [-1.0, 1.0] as [CGFloat] {
            let x = side * 22
            p.outlined(CGPath(roundedRect: CGRect(x: x - 10, y: -8, width: 20, height: 13), cornerWidth: 6.5, cornerHeight: 6.5, transform: &t), c.coat)
            let toes = CGMutablePath()
            toes.move(to: CGPoint(x: x - 3, y: 0)); toes.addLine(to: CGPoint(x: x - 3, y: 4))
            toes.move(to: CGPoint(x: x + 3, y: 0)); toes.addLine(to: CGPoint(x: x + 3, y: 4))
            p.line(toes.copy(using: &t)!, width: 1.6)
        }
    }

    // MARK: Painter

    private struct Painter<C: DoxieCanvas> {
        var canvas: C
        let palette: Palette
        /// Outline drawn first at double width, fill on top: a clean outer outline.
        mutating func outlined(_ path: CGPath, _ fill: CGColor) {
            canvas.stroke(path, palette.outline, width: outlineWidth * 2)
            canvas.fill(path, fill)
        }
        mutating func tube(_ path: CGPath, width: CGFloat, _ fill: CGColor) {
            canvas.stroke(path, palette.outline, width: width + outlineWidth * 2)
            canvas.stroke(path, fill, width: width)
        }
        mutating func line(_ path: CGPath, width: CGFloat) { canvas.stroke(path, palette.ink, width: width) }
        mutating func fill(_ path: CGPath, _ color: CGColor) { canvas.fill(path, color) }
    }
}

/// Where the dog gets painted: a Core Graphics context (icons, previews) or a pool of
/// Core Animation shape layers (the live dog, so the window server does the drawing).
protocol DoxieCanvas {
    mutating func stroke(_ path: CGPath, _ color: CGColor, width: CGFloat)
    mutating func fill(_ path: CGPath, _ color: CGColor)
}

struct ContextCanvas: DoxieCanvas {
    let ctx: CGContext
    func stroke(_ path: CGPath, _ color: CGColor, width: CGFloat) {
        ctx.addPath(path); ctx.setStrokeColor(color); ctx.setLineWidth(width)
        ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.strokePath()
    }
    func fill(_ path: CGPath, _ color: CGColor) {
        ctx.addPath(path); ctx.setFillColor(color); ctx.fillPath()
    }
}
