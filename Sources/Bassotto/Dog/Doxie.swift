import CoreGraphics
import Foundation

/// The dachshund, drawn exactly the way Desktop Goose draws its goose (same construction,
/// same sizes, same render order, same pixel snapping, same 2×2 dotted shadow), with only
/// the changes a dachshund needs:
///   • a longer body (±18 instead of ±11) and a shorter, lower neck;
///   • a snout with a round dark nose where the goose has its orange beak;
///   • two floppy ears and a little tail;
///   • four feet: a goose pair under the chest and another under the hips.
/// Coordinates are y-down screen points; `pos` is the ground point (the goose's `position`).
enum Doxie {
    struct Palette: Sendable {
        // Same relationships as the goose: body, a light outline a notch darker than the body
        // (also used for the belly), feet in the accent colour, black eyes.
        var body = hex(0xD9945B)       // goose: #ffffff
        var outline = hex(0xC27E48)    // goose: #d3d3d3
        var feet = hex(0x8A4B24)       // goose: #ffa500
        var nose = hex(0x2B1A12)       // goose's beak is #ffa500
        var ears = hex(0xD9945B)       // same as the body: the goose is one colour plus accents
        var eye = hex(0x000000)        // goose: #000000
        var shadowDot = hex(0xAAAAAA)  // NSColor.lightGray, one dot per 2×2 block
        var tongue = hex(0xF2788C)
        var tongueOutline = hex(0xD45A6E)
        static let classic = Palette()
        static let goose = Palette(body: hex(0xFFFFFF), outline: hex(0xD3D3D3), feet: hex(0xFFA500),
                                   nose: hex(0xFFA500), ears: hex(0xFFFFFF))
    }

    /// Everything that changes from frame to frame.
    struct State: Sendable {
        var pos: CGPoint
        var direction: CGFloat                 // degrees (0 = right, 90 = down), like the goose
        var feet: [CGPoint]                    // chest pair (left, right), hip pair (left, right)
        var neckLerp: CGFloat = 0              // the goose's neckLerpPercent
        var lying: CGFloat = 0                 // rest states come later; kept for the brain
        var eyesClosed = false
        var wag: CGFloat = 0                   // tail swing, radians
        var tongue: CGFloat = 0                // 0…1, tongue out (running)
        var tongueSwing: CGFloat = 0           // -1…1, tongue flapping

        init(pos: CGPoint, direction: CGFloat) {
            self.pos = pos
            self.direction = direction
            feet = (0..<4).map { Doxie.footHome($0, pos: pos, direction: direction) }
        }
    }

    // MARK: Rig (the goose's Rig constants, dog changes marked)

    static let underBodyRadius: CGFloat = 15, underBodyLength: CGFloat = 14, underBodyElevation: CGFloat = 9  // goose length 7
    static let bodyRadius: CGFloat = 22, bodyLength: CGFloat = 18, bodyElevation: CGFloat = 14                // goose length 11
    static let neckRadius: CGFloat = 13
    static let neckHeight1: CGFloat = 15, neckExtendForward1: CGFloat = 4     // goose 20 / 3: a dog's neck is shorter
    static let neckHeight2: CGFloat = 8, neckExtendForward2: CGFloat = 14     // goose 10 / 16
    static let headRadius1: CGFloat = 15, headLength1: CGFloat = 3
    static let headRadius2: CGFloat = 10, headLength2: CGFloat = 7            // goose 5: a dachshund's long snout
    static let eyeRadius: CGFloat = 2, eyeElevation: CGFloat = 3, ipd: CGFloat = 5, eyesForward: CGFloat = 5
    static let outlinePad: CGFloat = 2                                         // the goose's `num = 2`
    static let footRadius: CGFloat = 4, feetDistanceApart: CGFloat = 6
    static let chestOffset: CGFloat = 12, hipOffset: CGFloat = -12             // dog: two goose foot pairs

    /// The goose's GetFootHome (left at the point, right 6 to the side), once under the
    /// chest and once under the hips.
    static func footHome(_ i: Int, pos: CGPoint, direction: CGFloat) -> CGPoint {
        let f = unit(direction), right = unit(direction + 90)
        let base = add(pos, f, i < 2 ? chestOffset : hipOffset)
        return i % 2 == 0 ? base : add(base, right, feetDistanceApart)
    }

    // MARK: Render (the goose's Render, line for line)

    static func draw<C: DoxieCanvas>(_ c: inout C, _ s: State, palette p: Palette = .classic) {
        let pos = snap(s.pos)
        let fwd = unit(s.direction), right = unit(s.direction + 90), up = CGPoint(x: 0, y: -1)

        // UpdateRig
        let underbodyCenter = add(pos, up, underBodyElevation)
        let bodyCenter = add(pos, up, bodyElevation)
        let neckH = CGFloat(Int(lerp(neckHeight1, neckHeight2, s.neckLerp)))
        let neckF = CGFloat(Int(lerp(neckExtendForward1, neckExtendForward2, s.neckLerp)))
        let neckBase = add(bodyCenter, fwd, bodyLength + 4)                     // goose: 15 = 11 + 4
        let neckHeadPoint = add(add(neckBase, fwd, neckF), up, neckH)
        let head1End = add(add(neckHeadPoint, fwd, headLength1), up, -1)
        let head2End = add(head1End, fwd, headLength2)

        // Dog extras, positioned off the same rig points.
        // A long, slim tail rising from the rump, swinging when he wags.
        let tailBase = add(bodyCenter, fwd, -bodyLength - 2)
        let tailDir = unit(s.direction + 180 + s.wag * 180 / .pi)
        let tailMid = add(add(tailBase, tailDir, 7), up, 5)
        let tailTip = add(add(tailMid, unit(s.direction + 180 + s.wag * 1.6 * 180 / .pi), 7), up, 4)
        // Ears: the one on the far side is hidden behind the head unless he faces you or away.
        let nearSide: CGFloat = right.y >= 0 ? 1 : -1
        let showsBothEars = abs(right.y) < 0.35
        let earSides: [CGFloat] = showsBothEars ? [-1, 1] : [nearSide]
        let ears: [(CGPoint, CGPoint)] = earSides.map { side in
            let root = add(add(neckHeadPoint, right, side * 5), fwd, -2)
            let tip = add(add(add(root, up, -6 + s.neckLerp * 3), fwd, -2 - s.neckLerp * 5), right, side * 2)
            return (root, tip)
        }

        func line(_ a: CGPoint, _ b: CGPoint) -> CGPath {
            let path = CGMutablePath(); path.move(to: snap(a)); path.addLine(to: snap(b)); return path
        }
        func circle(_ center: CGPoint, _ r: CGFloat) -> CGPath {
            let q = snap(center); return CGPath(ellipseIn: CGRect(x: q.x - r, y: q.y - r, width: 2 * r, height: 2 * r), transform: nil)
        }

        // Feet, then the dotted shadow over them (exactly the goose's order).
        // Lying down, the paws are tucked under him.
        if s.lying < 0.5 { for foot in s.feet { c.fill(circle(foot, footRadius), p.feet) } }
        c.fill(shadow(center: pos, rx: 26, ry: 15), p.shadowDot)                 // goose: 20 × 15

        // Outline pass (part width + 2).
        let body = (add(bodyCenter, fwd, bodyLength), add(bodyCenter, fwd, -bodyLength))
        let tail = CGMutablePath()
        tail.move(to: snap(tailBase)); tail.addQuadCurve(to: snap(tailTip), control: snap(tailMid))
        c.stroke(tail, p.outline, width: 3 + outlinePad)
        c.stroke(line(body.0, body.1), p.outline, width: bodyRadius + outlinePad)
        c.stroke(line(neckBase, neckHeadPoint), p.outline, width: neckRadius + outlinePad)
        c.stroke(line(neckHeadPoint, head1End), p.outline, width: headRadius1 + outlinePad)
        c.stroke(line(head1End, head2End), p.outline, width: headRadius2 + outlinePad)
        // Underbody, in the outline colour.
        c.stroke(line(add(underbodyCenter, fwd, underBodyLength), add(underbodyCenter, fwd, -underBodyLength)),
                 p.outline, width: underBodyRadius)
        // Fill pass.
        c.stroke(tail, p.body, width: 3)
        c.stroke(line(body.0, body.1), p.body, width: bodyRadius)
        c.stroke(line(neckBase, neckHeadPoint), p.body, width: neckRadius)
        c.stroke(line(neckHeadPoint, head1End), p.body, width: headRadius1)
        c.stroke(line(head1End, head2End), p.body, width: headRadius2)
        // Ears (dog): floppy, body-coloured with the outline, like every other part.
        for (a, b) in ears {
            c.stroke(line(a, b), p.outline, width: 6 + outlinePad)
            c.stroke(line(a, b), p.ears, width: 6)
        }
        // Tongue: hangs from under the snout and flaps while he runs.
        if s.tongue > 0.05 {
            let root = add(add(head2End, fwd, -3), up, -3)
            let tip = add(add(add(root, up, -4 * s.tongue), fwd, -1 + s.tongueSwing), right, s.tongueSwing * 1.2)
            c.stroke(line(root, tip), p.tongueOutline, width: 4 + 1)
            c.stroke(line(root, tip), p.tongue, width: 4)
        }
        // A small dog nose at the snout tip (where the goose has its beak).
        c.fill(circle(add(head2End, fwd, 2), 2.6), p.nose)
        // Eyes: the goose's formula.
        let spread = CGPoint(x: 1.3, y: 0.4)
        for side in [-1, 1] as [CGFloat] {
            let e = add(add(add(neckHeadPoint, up, eyeElevation),
                            CGPoint(x: right.x * spread.x, y: right.y * spread.y), side * ipd), fwd, eyesForward)
            if s.eyesClosed {
                c.stroke(line(add(e, CGPoint(x: -2, y: 0)), add(e, CGPoint(x: 2, y: 0))), p.eye, width: 1.5)
            } else {
                c.fill(circle(e, eyeRadius), p.eye)
            }
        }
    }

    static func draw(_ ctx: CGContext, _ s: State, palette: Palette = .classic) {
        var canvas = ContextCanvas(ctx: ctx)
        draw(&canvas, s, palette: palette)
    }

    /// The goose's shadow: an ellipse filled with a 2×2 pattern that has one lit point,
    /// i.e. a dot on every other point of every other row.
    static func shadow(center: CGPoint, rx: CGFloat, ry: CGFloat) -> CGPath {
        let path = CGMutablePath()
        var y = (center.y - ry).rounded(.down)
        while y <= center.y + ry {
            var x = (center.x - rx).rounded(.down)
            x -= x.truncatingRemainder(dividingBy: 2)
            let yy = y - y.truncatingRemainder(dividingBy: 2)
            if y == yy {
                while x <= center.x + rx {
                    let dx = (x + 0.5 - center.x) / rx, dy = (y + 0.5 - center.y) / ry
                    if dx * dx + dy * dy <= 1 { path.addRect(CGRect(x: x, y: y, width: 1, height: 1)) }
                    x += 2
                }
            }
            y += 1
        }
        return path
    }

    static func unit(_ degrees: CGFloat) -> CGPoint {
        let r = degrees * .pi / 180
        return CGPoint(x: cos(r), y: sin(r))
    }

    static func add(_ a: CGPoint, _ b: CGPoint, _ m: CGFloat = 1) -> CGPoint { CGPoint(x: a.x + b.x * m, y: a.y + b.y * m) }
    /// The goose snaps every point to whole pixels (ToIntPoint truncates).
    static func snap(_ p: CGPoint) -> CGPoint { CGPoint(x: CGFloat(Int(p.x)), y: CGFloat(Int(p.y))) }
    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
    static func hex(_ v: UInt32) -> CGColor {
        CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
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
