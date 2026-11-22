import SwiftUI

/// The dachshund, drawn in an outlined kawaii style: warm dark outline, soft flat fills,
/// happy closed eyes, long floppy ears. Everything is designed on a 200×112 grid
/// (ground at y = 104) and scaled when drawn.
enum Kawaii {
    static let canvas = CGSize(width: 200, height: 112)
    static let ground: CGFloat = 104

    struct Palette {
        // Line-art mascot look: one soft cream, a charcoal outline, faces made of lines.
        var coat = Color(red: 0.95, green: 0.90, blue: 0.82)
        var coatDark = Color(red: 0.89, green: 0.82, blue: 0.71)   // ears, far legs
        var cream = Color(red: 0.95, green: 0.90, blue: 0.82)      // muzzle: same as coat
        var ink = Color(red: 0.16, green: 0.14, blue: 0.13)
        static let classic = Palette()
    }

    enum Pose: Equatable {
        case rest, sleep, walk
    }

    /// Everything that moves, as a function of loop progress `u` (0..<1) so every
    /// animation loops seamlessly once pre-rendered into frames.
    struct Motion {
        var u: Double = 0
        var walking: Bool = false

        private var turn: Double { u * 2 * .pi }
        var breath: CGFloat { CGFloat(sin(turn)) }                            // one breath per loop
        var wag: Angle { .degrees(sin(turn * (walking ? 2 : 6)) * 14) }
        var stride: Double { turn }                                           // one step cycle per loop
        func zzz(_ i: Int) -> Double { (u + Double(i) / 3).truncatingRemainder(dividingBy: 1) }
        var earLag: Angle { .degrees(walking ? sin(stride - 0.9) * 10 : 0) }
    }

    // MARK: Entry point

    static func draw(_ ctx: inout GraphicsContext, pose: Pose, motion: Motion,
                     palette p: Palette = .classic, scale: CGFloat) {
        ctx.scaleBy(x: scale, y: scale)
        switch pose {
        case .rest: rest(&ctx, motion, p)
        case .sleep: sleep(&ctx, motion, p)
        case .walk: walk(&ctx, motion, p)
        }
    }

    // MARK: Poses

    private static func rest(_ ctx: inout GraphicsContext, _ m: Motion, _ p: Palette) {
        let g = ground
        shadow(&ctx, x: 30, w: 150)
        var breathing = ctx
        breathe(&breathing, m.breath * 0.012)
        lyingBody(&breathing, p, tailUp: true, wag: m.wag)
        head(&breathing, p, cx: 66, cy: 52, asleep: false)
        paw(&ctx, p, x: 36, y: g - 15)
        paw(&ctx, p, x: 72, y: g - 15)
    }

    private static func sleep(_ ctx: inout GraphicsContext, _ m: Motion, _ p: Palette) {
        let g = ground
        shadow(&ctx, x: 24, w: 160)
        var breathing = ctx
        breathe(&breathing, m.breath * 0.02)
        lyingBody(&breathing, p, tailUp: false, wag: .zero)
        paw(&ctx, p, x: 30, y: g - 15)
        paw(&ctx, p, x: 64, y: g - 15)
        var tilted = breathing
        tilted.translateBy(x: 62, y: 64); tilted.rotate(by: .degrees(-7)); tilted.translateBy(x: -62, y: -64)
        head(&tilted, p, cx: 62, cy: 64, asleep: true)

        // Nose bubble swells as he breathes in.
        let r = 3 + (m.breath + 1) * 2.8
        let (bx, by) = (70 + r * 0.8, 74 + r * 0.2)  // grows out of the nostril
        let bubble = Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2))
        ctx.fill(bubble, with: .color(.white.opacity(0.55)))
        ctx.stroke(bubble, with: .color(p.ink), lineWidth: 1.8)
        ctx.fill(Path(ellipseIn: CGRect(x: bx - r * 0.55, y: by - r * 0.6, width: r * 0.5, height: r * 0.4)),
                 with: .color(.white))

        // Zzz drifting up and fading, staggered.
        for i in 0..<3 {
            let t = m.zzz(i)
            let size = 11 + t * 12
            var z = ctx
            z.opacity = t < 0.15 ? t / 0.15 : (1 - t) / 0.85
            z.addFilter(.shadow(color: p.ink, radius: 0.6))
            z.addFilter(.shadow(color: p.ink.opacity(0.5), radius: 0, x: 0, y: 1.5))
            z.draw(Text("z").font(.system(size: size, weight: .black, design: .rounded)).foregroundStyle(.white),
                   at: CGPoint(x: 96 + t * 40, y: 50 - t * 40))
        }
    }

    private static func walk(_ ctx: inout GraphicsContext, _ m: Motion, _ p: Palette) {
        let g = ground
        let bob = m.walking ? -abs(sin(m.stride)) * 2.2 : 0
        shadow(&ctx, x: 34, w: 140)
        var dog = ctx
        dog.translateBy(x: 0, y: bob)

        func leg(_ x: CGFloat, _ phase: Double, far: Bool) {
            let swing = m.walking ? CGFloat(sin(m.stride + phase)) * 4 : 0
            let lift = m.walking ? max(0, CGFloat(sin(m.stride + phase))) * 3 : 0
            let rect = CGRect(x: x + swing, y: g - 22 - lift - bob, width: 15, height: 21)
            outlined(&dog, Path(roundedRect: rect, cornerRadius: 7.5), far ? p.coatDark : p.coat, p)
        }

        // Tail, wagging from the rump.
        var tail = dog
        tail.translateBy(x: 44, y: g - 40)
        tail.rotate(by: m.wag)
        var tp = Path()
        tp.move(to: .zero)
        tp.addQuadCurve(to: CGPoint(x: -14, y: -24), control: CGPoint(x: -16, y: -4))
        tube(&tail, tp, width: 6, p.coat, p)

        leg(56, .pi, far: true); leg(124, 0, far: true)             // far side, slightly darker
        outlined(&dog, Path(roundedRect: CGRect(x: 40, y: g - 52, width: 118, height: 36), cornerRadius: 18), p.coat, p)
        leg(46, 0, far: false); leg(134, .pi, far: false)           // near side

        // Head in profile, facing right, with the same little tuft on top.
        var tuft = Path()
        tuft.move(to: CGPoint(x: 146, y: g - 82))
        tuft.addQuadCurve(to: CGPoint(x: 151, y: g - 94), control: CGPoint(x: 143, y: g - 92))
        tuft.addQuadCurve(to: CGPoint(x: 156, y: g - 86), control: CGPoint(x: 154, y: g - 90))
        tuft.addQuadCurve(to: CGPoint(x: 163, y: g - 91), control: CGPoint(x: 159, y: g - 92))
        tuft.addQuadCurve(to: CGPoint(x: 162, y: g - 81), control: CGPoint(x: 166, y: g - 86))
        tuft.closeSubpath()
        outlined(&dog, tuft, p.coat, p)
        outlined(&dog, Path(ellipseIn: CGRect(x: 128, y: g - 86, width: 50, height: 46)), p.coat, p)
        outlined(&dog, Path(roundedRect: CGRect(x: 160, y: g - 66, width: 34, height: 20), cornerRadius: 10), p.cream, p, line: 2.6)
        dog.fill(Path(roundedRect: CGRect(x: 186, y: g - 66, width: 10, height: 8), cornerRadius: 4), with: .color(p.ink))
        var eye = Path()
        eye.move(to: CGPoint(x: 156, y: g - 68)); eye.addQuadCurve(to: CGPoint(x: 166, y: g - 68), control: CGPoint(x: 161, y: g - 75))
        line(&dog, eye, 2.8, p)
        var smile = Path()
        smile.move(to: CGPoint(x: 176, y: g - 52)); smile.addQuadCurve(to: CGPoint(x: 186, y: g - 54), control: CGPoint(x: 182, y: g - 49))
        line(&dog, smile, 2.2, p)

        // Floppy ear, hanging back from the top of the head and swinging a beat late.
        var ear = dog
        ear.translateBy(x: 146, y: g - 80)
        ear.rotate(by: m.earLag)
        var e = Path()
        e.move(to: .zero)
        e.addCurve(to: CGPoint(x: -10, y: 40), control1: CGPoint(x: -14, y: 4), control2: CGPoint(x: -20, y: 34))
        e.addCurve(to: CGPoint(x: 6, y: 22), control1: CGPoint(x: -2, y: 46), control2: CGPoint(x: 8, y: 34))
        e.closeSubpath()
        outlined(&ear, e, p.coatDark, p)
    }

    // MARK: Parts

    private static func lyingBody(_ ctx: inout GraphicsContext, _ p: Palette, tailUp: Bool, wag: Angle) {
        let g = ground
        var tail = ctx
        var tp = Path()
        if tailUp {
            tail.translateBy(x: 168, y: g - 26)
            tail.rotate(by: wag)
            tp.move(to: .zero); tp.addQuadCurve(to: CGPoint(x: 14, y: -26), control: CGPoint(x: 18, y: -4))
        } else {
            tp.move(to: CGPoint(x: 168, y: g - 12)); tp.addQuadCurve(to: CGPoint(x: 192, y: g - 6), control: CGPoint(x: 182, y: g - 2))
        }
        tube(&tail, tp, width: 6, p.coat, p)
        outlined(&ctx, Path(roundedRect: CGRect(x: 58, y: g - 40, width: 116, height: 40), cornerRadius: 20), p.coat, p)
        outlined(&ctx, Path(roundedRect: CGRect(x: 142, y: g - 14, width: 26, height: 14), cornerRadius: 7), p.coat, p)
    }

    private static func head(_ ctx: inout GraphicsContext, _ p: Palette, cx: CGFloat, cy: CGFloat, asleep: Bool) {
        // A little tuft of hair on top, drawn first so the head overlaps its base.
        var tuft = Path()
        tuft.move(to: CGPoint(x: cx - 8, y: cy - 22))
        tuft.addQuadCurve(to: CGPoint(x: cx - 1, y: cy - 34), control: CGPoint(x: cx - 10, y: cy - 32))
        tuft.addQuadCurve(to: CGPoint(x: cx + 3, y: cy - 26), control: CGPoint(x: cx + 1, y: cy - 30))
        tuft.addQuadCurve(to: CGPoint(x: cx + 10, y: cy - 31), control: CGPoint(x: cx + 6, y: cy - 32))
        tuft.addQuadCurve(to: CGPoint(x: cx + 9, y: cy - 21), control: CGPoint(x: cx + 13, y: cy - 26))
        tuft.closeSubpath()
        outlined(&ctx, tuft, p.coat, p)
        outlined(&ctx, Path(ellipseIn: CGRect(x: cx - 31, y: cy - 26, width: 62, height: 52)), p.coat, p)
        outlined(&ctx, Path(ellipseIn: CGRect(x: cx - 15, y: cy + 2, width: 30, height: 22)), p.cream, p, line: 2.6)
        floppyEar(&ctx, p, x: cx - 22, y: cy - 16, side: -1)
        floppyEar(&ctx, p, x: cx + 22, y: cy - 16, side: 1)
        for ex in [cx - 12, cx + 12] {
            var e = Path()
            if asleep {
                e.move(to: CGPoint(x: ex - 5, y: cy - 4)); e.addQuadCurve(to: CGPoint(x: ex + 5, y: cy - 4), control: CGPoint(x: ex, y: cy + 1))
            } else {
                e.move(to: CGPoint(x: ex - 5, y: cy - 2)); e.addQuadCurve(to: CGPoint(x: ex + 5, y: cy - 2), control: CGPoint(x: ex, y: cy - 9))
            }
            line(&ctx, e, 2.8, p)
        }
        ctx.fill(Path(roundedRect: CGRect(x: cx - 5, y: cy + 5, width: 10, height: 7), cornerRadius: 3.5), with: .color(p.ink))
        var mouth = Path()
        mouth.move(to: CGPoint(x: cx - 6, y: cy + 15)); mouth.addQuadCurve(to: CGPoint(x: cx, y: cy + 14), control: CGPoint(x: cx - 3, y: cy + 19))
        mouth.addQuadCurve(to: CGPoint(x: cx + 6, y: cy + 15), control: CGPoint(x: cx + 3, y: cy + 19))
        mouth.move(to: CGPoint(x: cx, y: cy + 12)); mouth.addLine(to: CGPoint(x: cx, y: cy + 14))
        line(&ctx, mouth, 2.2, p)
    }

    private static func floppyEar(_ ctx: inout GraphicsContext, _ p: Palette, x: CGFloat, y: CGFloat, side: CGFloat) {
        let l: CGFloat = 46
        var e = Path()
        e.move(to: CGPoint(x: x, y: y))
        e.addCurve(to: CGPoint(x: x + side * 14, y: y + l),
                   control1: CGPoint(x: x + side * 16, y: y + 2), control2: CGPoint(x: x + side * 22, y: y + l - 4))
        e.addCurve(to: CGPoint(x: x - side * 2, y: y + l * 0.55),
                   control1: CGPoint(x: x + side * 6, y: y + l + 4), control2: CGPoint(x: x - side * 4, y: y + l * 0.85))
        e.closeSubpath()
        outlined(&ctx, e, p.coatDark, p)
    }

    private static func paw(_ ctx: inout GraphicsContext, _ p: Palette, x: CGFloat, y: CGFloat) {
        outlined(&ctx, Path(roundedRect: CGRect(x: x, y: y, width: 24, height: 15), cornerRadius: 7.5), p.coat, p)
        var toes = Path()
        for dx in [8.0, 16.0] { toes.move(to: CGPoint(x: x + dx, y: y + 9)); toes.addLine(to: CGPoint(x: x + dx, y: y + 14)) }
        line(&ctx, toes, 2, p)
    }

    // MARK: Primitives

    private static let stroke: CGFloat = 3

    private static func outlined(_ ctx: inout GraphicsContext, _ path: Path, _ fill: Color, _ p: Palette, line w: CGFloat = stroke) {
        ctx.fill(path, with: .color(fill))
        ctx.stroke(path, with: .color(p.ink), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }

    private static func tube(_ ctx: inout GraphicsContext, _ path: Path, width: CGFloat, _ fill: Color, _ p: Palette) {
        ctx.stroke(path, with: .color(p.ink), style: StrokeStyle(lineWidth: width + stroke * 2, lineCap: .round, lineJoin: .round))
        ctx.stroke(path, with: .color(fill), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private static func line(_ ctx: inout GraphicsContext, _ path: Path, _ w: CGFloat, _ p: Palette) {
        ctx.stroke(path, with: .color(p.ink), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }

    private static func shadow(_ ctx: inout GraphicsContext, x: CGFloat, w: CGFloat) {
        ctx.fill(Path(ellipseIn: CGRect(x: x, y: ground - 3, width: w, height: 8)), with: .color(.black.opacity(0.12)))
    }

    /// Breathing: a tiny vertical stretch anchored at the ground.
    private static func breathe(_ ctx: inout GraphicsContext, _ amount: CGFloat) {
        ctx.translateBy(x: 0, y: ground)
        ctx.scaleBy(x: 1, y: 1 + amount)
        ctx.translateBy(x: 0, y: -ground)
    }
}
