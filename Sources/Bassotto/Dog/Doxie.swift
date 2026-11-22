import CoreGraphics
import Foundation

/// The dachshund, built like a desktop goose: a handful of flat shapes laid out along
/// his heading, seen from slightly above, so he can face and walk in any direction.
/// Coordinates are screen-like (y grows downwards); `pos` is the ground under his belly.
/// Height is drawn as an upward offset, which is what sells the top-down look.
enum Doxie {
    struct Palette: Sendable {
        var coat = CGColor(srgbRed: 0.74, green: 0.42, blue: 0.20, alpha: 1)
        var dark = CGColor(srgbRed: 0.52, green: 0.27, blue: 0.11, alpha: 1)      // ears, legs
        var outline = CGColor(srgbRed: 0.36, green: 0.18, blue: 0.07, alpha: 1)
        var ink = CGColor(srgbRed: 0.12, green: 0.07, blue: 0.05, alpha: 1)
        var shadow = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.13)
        static let classic = Palette()
        /// Everything black: for template (menu bar) icons.
        static let silhouette: Palette = {
            let black = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
            return Palette(coat: black, dark: black, outline: black, ink: black,
                           shadow: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0))
        }()
    }

    /// Everything the rig needs for one frame.
    struct Pose: Sendable {
        var pos: CGPoint
        var heading: CGFloat                 // radians, screen space (y down)
        var feet: [CGPoint]                  // FL, FR, BL, BR
        var footLift: [CGFloat] = [0, 0, 0, 0]
        var bob: CGFloat = 0                 // extra body height while trotting
        var crouch: CGFloat = 0              // 0…1, lying down
        var wag: CGFloat = 0                 // tail angle offset
        var earFlap: CGFloat = 0             // 0…1, ears blown outwards when running
        var eyesClosed = false
        var mouthOpen = false
    }

    /// Where each foot wants to stand relative to the body (along, across).
    static let footOffsets: [(CGFloat, CGFloat)] = [(17, -9), (17, 9), (-17, -9), (-17, 9)]

    static func restingFoot(_ i: Int, pos: CGPoint, heading: CGFloat) -> CGPoint {
        let d = CGPoint(x: cos(heading), y: sin(heading)), n = CGPoint(x: -d.y, y: d.x)
        let (a, c) = footOffsets[i]
        return CGPoint(x: pos.x + d.x * a + n.x * c, y: pos.y + d.y * a + n.y * c)
    }

    /// Where his mouth is (for carrying the cursor).
    static func mouth(_ p: Pose) -> CGPoint {
        CGPoint(x: p.pos.x + cos(p.heading) * 40, y: p.pos.y + sin(p.heading) * 40 - 17)
    }

    static func draw(_ ctx: CGContext, _ p: Pose, palette c: Palette = .classic) {
        var canvas = ContextCanvas(ctx: ctx)
        draw(&canvas, p, palette: c)
    }

    static func draw<C: DoxieCanvas>(_ ctx: inout C, _ p: Pose, palette c: Palette = .classic) {
        let d = CGPoint(x: cos(p.heading), y: sin(p.heading))
        let n = CGPoint(x: -d.y, y: d.x)
        func at(_ along: CGFloat, _ across: CGFloat = 0, up: CGFloat = 0) -> CGPoint {
            CGPoint(x: p.pos.x + d.x * along + n.x * across, y: p.pos.y + d.y * along + n.y * across - up)
        }
        let h: CGFloat = 12 * (1 - p.crouch * 0.75) + p.bob        // belly height
        let facingAway = d.y < -0.35                                // head behind the body

        func line(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat, _ fill: CGColor) {
            let path = CGMutablePath(); path.move(to: a); path.addLine(to: b)
            ctx.stroke(path, c.outline, width: w + 3)
            ctx.stroke(path, fill, width: w)
        }
        func blob(_ center: CGPoint, _ along: CGFloat, _ across: CGFloat, angle: CGFloat, _ fill: CGColor, outline: Bool = true) {
            var t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle)
            let path = CGPath(ellipseIn: CGRect(x: -along / 2, y: -across / 2, width: along, height: across), transform: &t)
            if outline { ctx.stroke(path, c.outline, width: 3) }
            ctx.fill(path, fill)
        }

        blob(p.pos, 70, 26, angle: p.heading, c.shadow, outline: false)

        // Stubby legs, hip to foot, tucked away when lying down.
        if p.crouch < 0.6 {
            let hips: [CGPoint] = footOffsets.map { at($0.0 * 0.9, $0.1 * 0.7, up: h - 2) }
            for i in [2, 3, 0, 1] {
                line(hips[i], CGPoint(x: p.feet[i].x, y: p.feet[i].y - p.footLift[i]), 5, c.dark)
            }
        }

        func head() {
            for side in [-1.0, 1.0] as [CGFloat] {                                    // floppy ears
                let spread = 9 + p.earFlap * 7
                blob(at(25 - p.earFlap * 4, side * spread, up: h + 4 + p.earFlap * 3),
                     11 + p.earFlap * 3, 7, angle: p.heading + side * (0.5 + p.earFlap * 0.8), c.dark)
            }
            blob(at(29, up: h + 9), 22, 20, angle: p.heading, c.coat)                 // skull
            line(at(31, up: h + 7), at(40, up: h + 5.5), 8.5, c.coat)                  // snout
            blob(at(42, up: h + 6), 4.6, 4.6, angle: 0, c.ink, outline: false)        // nose
            if p.mouthOpen { blob(at(37, up: h + 2.5), 5, 3.5, angle: p.heading, c.ink, outline: false) }
            for side in [-1.0, 1.0] as [CGFloat] {                                    // eyes
                let e = at(26, side * 5.5, up: h + 14)
                if p.eyesClosed {
                    let lid = CGMutablePath()
                    lid.move(to: CGPoint(x: e.x - 2.4, y: e.y)); lid.addLine(to: CGPoint(x: e.x + 2.4, y: e.y))
                    ctx.stroke(lid, c.ink, width: 1.6)
                } else {
                    blob(e, 3.6, 3.6, angle: 0, c.ink, outline: false)
                }
            }
        }

        if facingAway { head() }
        let tailBase = at(-27, up: h + 3)                                             // wagging tail
        let tailDir = p.heading + .pi + p.wag
        line(tailBase, CGPoint(x: tailBase.x + cos(tailDir) * 13, y: tailBase.y + sin(tailDir) * 13 - 8), 4.5, c.coat)
        line(at(-24, up: h), at(20, up: h), 21, c.coat)                               // the sausage
        if !facingAway { head() }
    }
}

/// Where the dog gets painted: a Core Graphics context (icons) or a pool of
/// Core Animation shape layers (the live dog, so the window server does the drawing).
protocol DoxieCanvas {
    mutating func stroke(_ path: CGPath, _ color: CGColor, width: CGFloat)
    mutating func fill(_ path: CGPath, _ color: CGColor)
}

struct ContextCanvas: DoxieCanvas {
    let ctx: CGContext
    func stroke(_ path: CGPath, _ color: CGColor, width: CGFloat) {
        ctx.addPath(path); ctx.setStrokeColor(color); ctx.setLineWidth(width); ctx.setLineCap(.round); ctx.strokePath()
    }
    func fill(_ path: CGPath, _ color: CGColor) {
        ctx.addPath(path); ctx.setFillColor(color); ctx.fillPath()
    }
}
