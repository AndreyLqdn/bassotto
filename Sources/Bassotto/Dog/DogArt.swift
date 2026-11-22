import SwiftUI

/// The dachshund in a line-art mascot style: one flowing contour, cream fill, charcoal
/// line, curly long-haired ears and tail, a happy closed eye and a smile along the snout.
/// Designed on a 200×124 grid. The ground (or the Dock edge he lies on) is y = 104;
/// the 20 units below it are for paws dangling over the edge while he sleeps.
enum DogArt {
    static let canvas = CGSize(width: 200, height: 124)
    static let ground: CGFloat = 104

    struct Palette {
        var coat = Color(red: 0.96, green: 0.91, blue: 0.83)
        var shade = Color(red: 0.90, green: 0.83, blue: 0.72)     // far legs, inner ear
        var ink = Color(red: 0.17, green: 0.15, blue: 0.14)
        static let classic = Palette()
    }

    enum Pose: Hashable { case stand, trot, run, sleep }

    /// Motion as a function of loop progress `u` (0..<1) so loops are seamless.
    struct Motion {
        var u: Double = 0
        var pose: Pose = .stand
        var turn: Double { u * 2 * .pi }
    }

    static let line: CGFloat = 2.8

    static func draw(_ ctx: inout GraphicsContext, pose: Pose, u: Double,
                     palette p: Palette = .classic, scale: CGFloat) {
        ctx.scaleBy(x: scale, y: scale)
        let m = Motion(u: u, pose: pose)
        switch pose {
        case .stand, .trot, .run: profile(&ctx, m, p)
        case .sleep: sleeping(&ctx, m, p)
        }
    }

    // MARK: - Profile (stand / trot / run), facing right

    private static func profile(_ ctx: inout GraphicsContext, _ m: Motion, _ p: Palette) {
        let g = ground
        let running = m.pose == .run, moving = m.pose != .stand
        let legSwing = running ? 34.0 : 16.0
        let bounce: CGFloat = moving ? -abs(CGFloat(sin(m.turn))) * (running ? 3.5 : 2) : 0
        let breath: CGFloat = m.pose == .stand ? CGFloat(sin(m.turn)) * 0.6 : 0

        ctx.fill(Path(ellipseIn: CGRect(x: 44, y: g - 3, width: 110, height: 7)), with: .color(.black.opacity(0.10)))

        var dog = ctx
        dog.translateBy(x: -10, y: bounce)
        if running {           // lean into the sprint
            dog.translateBy(x: 100, y: g); dog.rotate(by: .degrees(-4)); dog.translateBy(x: -100, y: -g)
        }

        // Tail: feathered plume. Wags while standing, streams back while running.
        let tailAngle: Angle = switch m.pose {
        case .stand: .degrees(sin(m.turn * 3) * 12)
        case .trot: .degrees(sin(m.turn * 2) * 10)
        case .run: .degrees(28 + sin(m.turn * 2) * 6)
        case .sleep: .zero
        }
        var tail = dog
        tail.translateBy(x: 44, y: 66)
        tail.rotate(by: tailAngle)
        outlined(&tail, tailPath(), p.coat, p)

        // Legs: diagonal pairs move together.
        func leg(_ hip: CGPoint, phase: Double, far: Bool) {
            let swing = moving ? Angle.degrees(sin(m.turn + phase) * legSwing) : .zero
            var l = dog
            l.translateBy(x: hip.x, y: hip.y)
            l.rotate(by: swing)
            let length = g - hip.y - bounce
            outlined(&l, legPath(length: length), far ? p.shade : p.coat, p)
        }
        // All legs go under the body so it covers their tops.
        leg(CGPoint(x: 60, y: 80), phase: .pi, far: true)
        leg(CGPoint(x: 138, y: 82), phase: 0, far: true)
        leg(CGPoint(x: 72, y: 82), phase: 0, far: false)
        leg(CGPoint(x: 150, y: 84), phase: .pi, far: false)

        // Body: one long, low contour with a deep chest.
        var body = Path()
        body.move(to: CGPoint(x: 46, y: 66))
        body.addCurve(to: CGPoint(x: 140, y: 58 + breath), control1: CGPoint(x: 72, y: 56), control2: CGPoint(x: 112, y: 56))
        body.addCurve(to: CGPoint(x: 150, y: 90), control1: CGPoint(x: 158, y: 62), control2: CGPoint(x: 160, y: 84))
        body.addCurve(to: CGPoint(x: 56, y: 88), control1: CGPoint(x: 124, y: 96 + breath), control2: CGPoint(x: 84, y: 92))
        body.addCurve(to: CGPoint(x: 46, y: 66), control1: CGPoint(x: 40, y: 86), control2: CGPoint(x: 38, y: 70))
        body.closeSubpath()
        outlined(&dog, body, p.coat, p)

        // Chest fluff.
        var fluff = Path()
        fluff.move(to: CGPoint(x: 150, y: 72)); fluff.addQuadCurve(to: CGPoint(x: 147, y: 79), control: CGPoint(x: 145, y: 75))
        fluff.move(to: CGPoint(x: 152, y: 80)); fluff.addQuadCurve(to: CGPoint(x: 148, y: 87), control: CGPoint(x: 146, y: 83))
        stroke(&dog, fluff, p, width: 2)

        // Head (with ears flying back when running).
        var head = dog
        if running { head.translateBy(x: 4, y: 0) }
        // Mascot proportions: a big head on a long little body.
        head.translateBy(x: 146, y: 64); head.scaleBy(x: 1.3, y: 1.3); head.translateBy(x: -146, y: -64)
        profileHead(&head, p, earAngle: running ? .degrees(48 + sin(m.turn * 2) * 10)
                                     : moving ? .degrees(sin(m.turn - 0.9) * 8) : .degrees(sin(m.turn) * 2))
    }

    static func profileHead(_ ctx: inout GraphicsContext, _ p: Palette, earAngle: Angle) {
        // Neck + skull + long snout as one shape.
        var head = Path()
        head.move(to: CGPoint(x: 140, y: 62))
        head.addCurve(to: CGPoint(x: 150, y: 36), control1: CGPoint(x: 136, y: 50), control2: CGPoint(x: 140, y: 38))
        head.addCurve(to: CGPoint(x: 172, y: 40), control1: CGPoint(x: 158, y: 30), control2: CGPoint(x: 168, y: 32))
        head.addCurve(to: CGPoint(x: 194, y: 50), control1: CGPoint(x: 178, y: 44), control2: CGPoint(x: 188, y: 46))
        head.addCurve(to: CGPoint(x: 193, y: 59), control1: CGPoint(x: 199, y: 52), control2: CGPoint(x: 198, y: 58))
        head.addCurve(to: CGPoint(x: 166, y: 64), control1: CGPoint(x: 184, y: 62), control2: CGPoint(x: 174, y: 64))
        head.addCurve(to: CGPoint(x: 150, y: 74), control1: CGPoint(x: 158, y: 64), control2: CGPoint(x: 152, y: 68))
        head.closeSubpath()
        outlined(&ctx, head, p.coat, p)

        // Curly tuft on the forehead (the mascot's signature).
        var tuft = Path()
        tuft.move(to: CGPoint(x: 153, y: 35))
        tuft.addCurve(to: CGPoint(x: 158, y: 29), control1: CGPoint(x: 151, y: 31), control2: CGPoint(x: 154, y: 28))
        tuft.addCurve(to: CGPoint(x: 164, y: 33), control1: CGPoint(x: 161, y: 27), control2: CGPoint(x: 165, y: 29))
        outlined(&ctx, tuft, p.coat, p)

        ctx.fill(Path(ellipseIn: CGRect(x: 189.5, y: 47.5, width: 8.5, height: 7.5)), with: .color(p.ink))   // nose
        var face = Path()
        face.move(to: CGPoint(x: 160, y: 46)); face.addQuadCurve(to: CGPoint(x: 170, y: 45), control: CGPoint(x: 165, y: 39))  // happy eye
        face.move(to: CGPoint(x: 174, y: 57)); face.addQuadCurve(to: CGPoint(x: 189, y: 57), control: CGPoint(x: 182, y: 63))  // smile
        face.move(to: CGPoint(x: 189, y: 57)); face.addLine(to: CGPoint(x: 191, y: 55))
        stroke(&ctx, face, p, width: 2.6)

        // Long, wavy ear hanging from the back of the skull.
        var ear = ctx
        ear.translateBy(x: 152, y: 40)
        ear.rotate(by: earAngle)
        outlined(&ear, earPath(), p.coat, p)
        var inner = Path()
        inner.move(to: CGPoint(x: -1, y: 10)); inner.addQuadCurve(to: CGPoint(x: -3, y: 30), control: CGPoint(x: 1, y: 20))
        stroke(&ear, inner, p, width: 1.8)
    }

    private static func earPath() -> Path {
        var e = Path()
        e.move(to: CGPoint(x: 4, y: 0))
        e.addCurve(to: CGPoint(x: 7, y: 34), control1: CGPoint(x: 10, y: 10), control2: CGPoint(x: 10, y: 26))
        // Wavy, long-haired bottom edge.
        e.addQuadCurve(to: CGPoint(x: 1, y: 38), control: CGPoint(x: 6, y: 40))
        e.addQuadCurve(to: CGPoint(x: -5, y: 38), control: CGPoint(x: -2, y: 42))
        e.addQuadCurve(to: CGPoint(x: -10, y: 33), control: CGPoint(x: -10, y: 39))
        e.addCurve(to: CGPoint(x: -4, y: 0), control1: CGPoint(x: -12, y: 22), control2: CGPoint(x: -10, y: 6))
        e.closeSubpath()
        return e
    }

    private static func tailPath() -> Path {
        var t = Path()
        t.move(to: CGPoint(x: 2, y: -4))
        t.addCurve(to: CGPoint(x: -26, y: -20), control1: CGPoint(x: -8, y: -10), control2: CGPoint(x: -18, y: -18))
        // Feathered underside.
        t.addQuadCurve(to: CGPoint(x: -22, y: -12), control: CGPoint(x: -27, y: -14))
        t.addQuadCurve(to: CGPoint(x: -14, y: -6), control: CGPoint(x: -16, y: -6))
        t.addQuadCurve(to: CGPoint(x: -6, y: -1), control: CGPoint(x: -8, y: 0))
        t.addQuadCurve(to: CGPoint(x: 2, y: 4), control: CGPoint(x: -2, y: 4))
        t.closeSubpath()
        return t
    }

    private static func legPath(length: CGFloat) -> Path {
        var l = Path()
        l.move(to: CGPoint(x: -7, y: -8))
        l.addLine(to: CGPoint(x: -7, y: length - 7))
        l.addQuadCurve(to: CGPoint(x: 0, y: length), control: CGPoint(x: -7, y: length))
        l.addLine(to: CGPoint(x: 7, y: length))
        l.addQuadCurve(to: CGPoint(x: 7, y: length - 7), control: CGPoint(x: 12, y: length - 1))
        l.addLine(to: CGPoint(x: 7, y: -8))
        l.closeSubpath()
        return l
    }

    // MARK: - Sleeping on the Dock edge (front view, paws dangling)

    private static func sleeping(_ ctx: inout GraphicsContext, _ m: Motion, _ p: Palette) {
        let ledge = ground
        let breath = CGFloat(sin(m.turn))

        // Everything above the ledge; the body continues out of sight below it.
        var above = ctx
        above.clip(to: Path(CGRect(x: 0, y: 0, width: canvas.width, height: ledge)))

        // Long back stretching to the right, rising and falling with his breath.
        var back = Path()
        back.move(to: CGPoint(x: 96, y: ledge))
        back.addCurve(to: CGPoint(x: 150, y: ledge - 26 - breath * 1.2), control1: CGPoint(x: 100, y: ledge - 30), control2: CGPoint(x: 128, y: ledge - 28 - breath))
        back.addCurve(to: CGPoint(x: 178, y: ledge), control1: CGPoint(x: 168, y: ledge - 24 - breath), control2: CGPoint(x: 178, y: ledge - 14))
        back.closeSubpath()
        outlined(&above, back, p.coat, p)
        var tail = Path()
        tail.move(to: CGPoint(x: 176, y: ledge - 8))
        tail.addCurve(to: CGPoint(x: 196, y: ledge - 2), control1: CGPoint(x: 184, y: ledge - 14), control2: CGPoint(x: 192, y: ledge - 10))
        tail.addQuadCurve(to: CGPoint(x: 186, y: ledge), control: CGPoint(x: 192, y: ledge + 2))
        outlined(&above, tail, p.coat, p)

        // Paws hanging over the edge.
        for x in [70.0, 100.0] {
            var paw = Path()
            paw.move(to: CGPoint(x: x, y: ledge - 6))
            paw.addLine(to: CGPoint(x: x, y: ledge + 8))
            paw.addQuadCurve(to: CGPoint(x: x + 8, y: ledge + 15), control: CGPoint(x: x, y: ledge + 15))
            paw.addQuadCurve(to: CGPoint(x: x + 16, y: ledge + 8), control: CGPoint(x: x + 16, y: ledge + 15))
            paw.addLine(to: CGPoint(x: x + 16, y: ledge - 6))
            paw.closeSubpath()
            outlined(&ctx, paw, p.coat, p)
            var toes = Path()
            toes.move(to: CGPoint(x: x + 5.5, y: ledge + 10)); toes.addLine(to: CGPoint(x: x + 5.5, y: ledge + 14))
            toes.move(to: CGPoint(x: x + 10.5, y: ledge + 10)); toes.addLine(to: CGPoint(x: x + 10.5, y: ledge + 14))
            stroke(&ctx, toes, p, width: 1.8)
        }

        // Head resting on the paws, facing us.
        let cx: CGFloat = 93, cy: CGFloat = ledge - 24
        var head = ctx
        head.translateBy(x: cx, y: cy); head.rotate(by: .degrees(-6)); head.translateBy(x: -cx, y: -cy)

        // Ears behind the head, draping down both sides with wavy tips.
        for side in [-1.0, 1.0] {
            var ear = head
            ear.translateBy(x: cx + side * 21, y: cy - 12)
            ear.rotate(by: .degrees(side * -10))
            ear.scaleBy(x: side, y: 1)
            outlined(&ear, earPath(), p.shade, p)
        }
        var skull = Path()
        skull.move(to: CGPoint(x: cx - 24, y: cy + 10))
        skull.addCurve(to: CGPoint(x: cx, y: cy - 22), control1: CGPoint(x: cx - 28, y: cy - 8), control2: CGPoint(x: cx - 16, y: cy - 22))
        skull.addCurve(to: CGPoint(x: cx + 24, y: cy + 10), control1: CGPoint(x: cx + 16, y: cy - 22), control2: CGPoint(x: cx + 28, y: cy - 8))
        skull.addCurve(to: CGPoint(x: cx, y: cy + 22), control1: CGPoint(x: cx + 20, y: cy + 20), control2: CGPoint(x: cx + 10, y: cy + 22))
        skull.addCurve(to: CGPoint(x: cx - 24, y: cy + 10), control1: CGPoint(x: cx - 10, y: cy + 22), control2: CGPoint(x: cx - 20, y: cy + 20))
        skull.closeSubpath()
        outlined(&head, skull, p.coat, p)

        // Tuft.
        var tuft = Path()
        tuft.move(to: CGPoint(x: cx - 8, y: cy - 20))
        tuft.addCurve(to: CGPoint(x: cx - 1, y: cy - 29), control1: CGPoint(x: cx - 11, y: cy - 26), control2: CGPoint(x: cx - 6, y: cy - 30))
        tuft.addCurve(to: CGPoint(x: cx + 7, y: cy - 27), control1: CGPoint(x: cx + 2, y: cy - 32), control2: CGPoint(x: cx + 6, y: cy - 31))
        tuft.addCurve(to: CGPoint(x: cx + 9, y: cy - 20), control1: CGPoint(x: cx + 11, y: cy - 26), control2: CGPoint(x: cx + 11, y: cy - 22))
        outlined(&head, tuft, p.coat, p)


        // Nose, little ᴥ mouth, sleepy eyes.
        head.fill(Path(ellipseIn: CGRect(x: cx - 5, y: cy + 4, width: 10, height: 7)), with: .color(p.ink))
        var face = Path()
        face.move(to: CGPoint(x: cx - 15, y: cy - 4)); face.addQuadCurve(to: CGPoint(x: cx - 6, y: cy - 4), control: CGPoint(x: cx - 10.5, y: cy))
        face.move(to: CGPoint(x: cx + 6, y: cy - 4)); face.addQuadCurve(to: CGPoint(x: cx + 15, y: cy - 4), control: CGPoint(x: cx + 10.5, y: cy))
        face.move(to: CGPoint(x: cx, y: cy + 11)); face.addLine(to: CGPoint(x: cx, y: cy + 14))
        face.move(to: CGPoint(x: cx - 6, y: cy + 14)); face.addQuadCurve(to: CGPoint(x: cx, y: cy + 14), control: CGPoint(x: cx - 3, y: cy + 18))
        face.addQuadCurve(to: CGPoint(x: cx + 6, y: cy + 14), control: CGPoint(x: cx + 3, y: cy + 18))
        stroke(&head, face, p, width: 2.2)

        // Zzz drifting up and fading, staggered.
        for i in 0..<3 {
            let t = (m.u + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            var z = ctx
            z.opacity = t < 0.15 ? t / 0.15 : (1 - t) / 0.85
            z.addFilter(.shadow(color: p.ink, radius: 0.5))
            z.draw(Text("z").font(.system(size: 10 + t * 12, weight: .heavy, design: .rounded)).foregroundStyle(.white),
                   at: CGPoint(x: 118 + t * 34, y: 52 - t * 40))
        }
    }

    // MARK: - Primitives

    nonisolated(unsafe) static var knockoutFills = false

    private static func outlined(_ ctx: inout GraphicsContext, _ path: Path, _ fill: Color, _ p: Palette) {
        if knockoutFills {
            var erase = ctx
            erase.blendMode = .clear
            erase.fill(path, with: .color(.black))
        } else {
            ctx.fill(path, with: .color(fill))
        }
        ctx.stroke(path, with: .color(p.ink), style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
    }

    private static func stroke(_ ctx: inout GraphicsContext, _ path: Path, _ p: Palette, width: CGFloat) {
        ctx.stroke(path, with: .color(p.ink), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - Icon

extension DogArt {
    /// The profile head, fitted into `rect`. With `knockout`, fills erase instead of
    /// painting, so a template icon shows clean lines only.
    static func headIcon(_ ctx: inout GraphicsContext, in rect: CGRect, palette: Palette = .classic, knockout: Bool = false) {
        let source = CGRect(x: 126, y: 18, width: 74, height: 64)   // head bounds on the design grid
        let s = min(rect.width / source.width, rect.height / source.height)
        ctx.translateBy(x: rect.midX - source.midX * s, y: rect.midY - source.midY * s)
        ctx.scaleBy(x: s, y: s)
        knockoutFills = knockout
        profileHead(&ctx, palette, earAngle: .zero)
        knockoutFills = false
    }
}
