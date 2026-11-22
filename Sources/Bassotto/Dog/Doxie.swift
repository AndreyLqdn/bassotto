import CoreGraphics
import Foundation

/// The dachshund, built the way Desktop Goose builds its goose: thick round-capped lines
/// for the body, neck and head, a thin outline pass underneath, round feet on the ground,
/// a soft shadow, and "height" faked by shifting parts straight up the screen.
/// Adapted for a dog: a long low sausage body, a short neck, a long snout with a nose,
/// floppy ears, a tail, and four feet instead of two.
/// Coordinates are y-down screen points; `pos` is the ground under his middle.
enum Doxie {
    struct Palette: Sendable {
        var coat = CGColor(srgbRed: 0.80, green: 0.49, blue: 0.26, alpha: 1)       // classic red
        var outline = CGColor(srgbRed: 0.55, green: 0.30, blue: 0.14, alpha: 1)    // also the belly
        var ears = CGColor(srgbRed: 0.50, green: 0.26, blue: 0.11, alpha: 1)
        var feet = CGColor(srgbRed: 0.45, green: 0.23, blue: 0.10, alpha: 1)
        var eye = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        var shadow = CGColor(srgbRed: 0.55, green: 0.55, blue: 0.55, alpha: 0.28)
        static let red = Palette()
        static let cream = Palette(coat: CGColor(srgbRed: 0.97, green: 0.91, blue: 0.80, alpha: 1),
                                   outline: CGColor(srgbRed: 0.80, green: 0.72, blue: 0.62, alpha: 1),
                                   ears: CGColor(srgbRed: 0.86, green: 0.64, blue: 0.42, alpha: 1),
                                   feet: CGColor(srgbRed: 0.78, green: 0.56, blue: 0.36, alpha: 1))
    }

    /// Everything that changes from frame to frame.
    struct State: Sendable {
        var pos: CGPoint
        var direction: CGFloat                 // degrees, like the goose (0 = right, 90 = down)
        var feet: [CGPoint]                    // front-left, front-right, back-left, back-right
        var neckLerp: CGFloat = 0              // 0 walking … 1 running: head low and forward
        var lying: CGFloat = 0                 // 0 standing … 1 lying down
        var eyesClosed = false
        var wag: CGFloat = 0                   // tail swing, radians

        init(pos: CGPoint, direction: CGFloat) {
            self.pos = pos
            self.direction = direction
            feet = (0..<4).map { Doxie.footHome($0, pos: pos, direction: direction) }
        }
    }

    // Rig sizes (the goose's are body 22/±11, neck 13, head 15 + 10, beak 9, eyes 2).
    static let bodyWidth: CGFloat = 20, bodyHalfLength: CGFloat = 17
    static let bellyWidth: CGFloat = 13, bellyHalfLength: CGFloat = 13
    static let neckWidth: CGFloat = 12, headWidth: CGFloat = 15, snoutWidth: CGFloat = 9
    static let outlinePad: CGFloat = 2

    /// Where each paw wants to stand: a pair under the chest and a pair under the hips.
    static func footHome(_ i: Int, pos: CGPoint, direction: CGFloat) -> CGPoint {
        let f = unit(direction), side = unit(direction + 90)
        let along: CGFloat = i < 2 ? 12 : -12
        let across: CGFloat = i % 2 == 0 ? -3.5 : 3.5
        return CGPoint(x: pos.x + f.x * along + side.x * across, y: pos.y + f.y * along + side.y * across)
    }

    static func draw<C: DoxieCanvas>(_ c: inout C, _ s: State, scale: CGFloat = 1, palette p: Palette = .red) {
        let k = scale
        let o = s.pos
        // Scale everything about the ground point.
        func P(_ v: CGPoint) -> CGPoint { CGPoint(x: o.x + (v.x - o.x) * k, y: o.y + (v.y - o.y) * k) }
        let f = unit(s.direction), side = unit(s.direction + 90), up = CGPoint(x: 0, y: -1)
        func add(_ a: CGPoint, _ b: CGPoint, _ m: CGFloat = 1) -> CGPoint { CGPoint(x: a.x + b.x * m, y: a.y + b.y * m) }

        // Rig (the goose's UpdateRig, lowered and lengthened for a dachshund).
        let lie = s.lying
        let bellyCenter = add(o, up, 6 - lie * 4)
        let bodyCenter = add(o, up, 10 - lie * 6)
        let neckHeight = lerp(9, 5, s.neckLerp) - lie * 3
        let neckReach = lerp(5, 12, s.neckLerp) + lie * 3
        let neckBase = add(bodyCenter, f, 15)
        let headPoint = add(add(neckBase, f, neckReach), up, neckHeight)
        let head1End = add(add(headPoint, f, 3), up, -1)
        let snoutEnd = add(head1End, f, 9)
        let tailBase = add(bodyCenter, f, -bodyHalfLength)
        let wagDir = unit(s.direction + 180 + s.wag * 180 / .pi)
        let tailTip = add(add(tailBase, wagDir, 9), up, 7 - lie * 5)

        func line(_ a: CGPoint, _ b: CGPoint) -> CGPath {
            let path = CGMutablePath(); path.move(to: P(a)); path.addLine(to: P(b)); return path
        }
        func circle(_ center: CGPoint, _ r: CGFloat) -> CGPath {
            let q = P(center); return CGPath(ellipseIn: CGRect(x: q.x - r * k, y: q.y - r * k, width: 2 * r * k, height: 2 * r * k), transform: nil)
        }

        // Floppy ears: hang down the sides of the head, blown back when he runs.
        let ears: [(CGPoint, CGPoint)] = ([-1.0, 1.0] as [CGFloat]).map { sd in
            let root = add(add(headPoint, side, sd * 6), up, 2)
            let hang = add(add(add(root, up, -8 + s.neckLerp * 4), f, -2 - s.neckLerp * 7), side, sd * (2 + s.neckLerp * 2))
            return (root, hang)
        }

        // 1. Soft shadow, then the round feet on the ground.
        let sh = P(o)
        c.fill(CGPath(ellipseIn: CGRect(x: sh.x - 26 * k, y: sh.y - 12 * k, width: 52 * k, height: 24 * k), transform: nil), p.shadow)
        for foot in s.feet { c.fill(circle(foot, 4), p.feet) }

        // 2. Outline pass: every part a little wider, in the outline colour.
        let parts: [(CGPoint, CGPoint, CGFloat)] = [
            (tailBase, tailTip, 5),
            (add(bodyCenter, f, bodyHalfLength), add(bodyCenter, f, -bodyHalfLength), bodyWidth),
            (neckBase, headPoint, neckWidth),
            (headPoint, head1End, headWidth),
            (head1End, snoutEnd, snoutWidth),
        ]
        for (a, b, w) in parts { c.stroke(line(a, b), p.outline, width: (w + outlinePad) * k) }
        for (a, b) in ears { c.stroke(line(a, b), p.outline, width: (7 + outlinePad) * k) }

        // 3. Belly (outline colour, like the goose's underbody), then the coat.
        c.stroke(line(add(bellyCenter, f, bellyHalfLength), add(bellyCenter, f, -bellyHalfLength)), p.outline, width: bellyWidth * k)
        for (a, b, w) in parts { c.stroke(line(a, b), p.coat, width: w * k) }
        for (a, b) in ears { c.stroke(line(a, b), p.ears, width: 7 * k) }

        // 4. Nose (where the goose has its beak) and eyes.
        c.fill(circle(add(snoutEnd, f, 2), 3), p.eye)
        let ipd = CGPoint(x: 1.3, y: 0.4)
        for sd in [-1.0, 1.0] as [CGFloat] {
            let e = add(add(add(headPoint, up, 3), CGPoint(x: side.x * ipd.x, y: side.y * ipd.y), sd * 5), f, 4)
            if s.eyesClosed {
                let lid = CGMutablePath()
                lid.move(to: P(add(e, CGPoint(x: -2.2, y: 0)))); lid.addLine(to: P(add(e, CGPoint(x: 2.2, y: 0))))
                c.stroke(lid, p.eye, width: 1.5 * k)
            } else {
                c.fill(circle(e, 2), p.eye)
            }
        }
    }

    static func draw(_ ctx: CGContext, _ s: State, scale: CGFloat = 1, palette: Palette = .red) {
        var canvas = ContextCanvas(ctx: ctx)
        draw(&canvas, s, scale: scale, palette: palette)
    }

    static func unit(_ degrees: CGFloat) -> CGPoint {
        let r = degrees * .pi / 180
        return CGPoint(x: cos(r), y: sin(r))
    }

    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
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
