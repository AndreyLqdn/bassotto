import SwiftUI

/// A flat, goose-style dachshund drawn from simple shapes, facing right.
/// Used as the stand-in dog until the Blender clips arrive, and as the source of truth
/// for proportions: very long body, stubby legs, big floppy ear, pointy snout.
enum Dachshund {
    static let size = CGSize(width: 96, height: 46)

    enum Palette {
        static let coat = Color(red: 0.73, green: 0.40, blue: 0.19)
        static let back = Color(red: 0.60, green: 0.31, blue: 0.14)
        static let belly = Color(red: 0.86, green: 0.58, blue: 0.36)
        static let ear = Color(red: 0.43, green: 0.21, blue: 0.09)
        static let ink = Color(red: 0.13, green: 0.08, blue: 0.06)
    }

    /// Pose inputs, all driven by one walk phase so the motion stays in sync.
    struct Pose {
        var phase: Double = 0      // radians, advances while walking
        var walking = false

        var bob: CGFloat { walking ? -abs(sin(phase)) * 1.6 : 0 }
        func legSwing(_ pair: Int) -> CGFloat { walking ? sin(phase + (pair == 0 ? 0 : .pi)) * 2.4 : 0 }
        func legLift(_ pair: Int) -> CGFloat { walking ? max(0, sin(phase + (pair == 0 ? 0 : .pi))) * 2 : 0 }
        var ear: Angle { .degrees(walking ? sin(phase - 0.9) * 14 : 0) }  // lags behind the body
        var tail: Angle { .degrees(walking ? sin(phase * 1.5) * 18 : 6) }
    }

    static func draw(_ ctx: inout GraphicsContext, pose: Pose) {
        let h = size.height

        // Ground shadow.
        ctx.fill(Path(ellipseIn: CGRect(x: 8, y: h - 4, width: 70, height: 5)),
                 with: .color(.black.opacity(0.14)))

        var dog = ctx
        dog.translateBy(x: 0, y: pose.bob)

        // Legs: diagonal pairs step together (back-left with front-right).
        let legs: [(x: CGFloat, pair: Int)] = [(16, 0), (25, 1), (56, 1), (65, 0)]
        for leg in legs {
            let rect = CGRect(x: leg.x, y: h - 11, width: 7, height: 10)
                .offsetBy(dx: pose.legSwing(leg.pair), dy: -pose.legLift(leg.pair))
            dog.fill(Path(roundedRect: rect, cornerRadius: 3.2), with: .color(Palette.back))
        }

        // Tail, wagging from the rump.
        var tail = dog
        tail.translateBy(x: 12, y: h - 25)
        tail.rotate(by: pose.tail)
        var tailPath = Path()
        tailPath.move(to: .zero)
        tailPath.addQuadCurve(to: CGPoint(x: -10, y: -9), control: CGPoint(x: -8, y: 0))
        tail.stroke(tailPath, with: .color(Palette.back), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))

        // The sausage.
        let body = CGRect(x: 9, y: h - 32, width: 64, height: 23)
        dog.fill(Path(roundedRect: body, cornerRadius: 11), with: .color(Palette.coat))
        dog.fill(Path(roundedRect: CGRect(x: 15, y: h - 32, width: 50, height: 6), cornerRadius: 3),
                 with: .color(Palette.back.opacity(0.55)))
        // Deep chest (the dachshund "keel") and a soft belly.
        dog.fill(Path(ellipseIn: CGRect(x: 48, y: h - 24, width: 24, height: 17)), with: .color(Palette.coat))
        dog.fill(Path(ellipseIn: CGRect(x: 24, y: h - 17, width: 34, height: 6)), with: .color(Palette.belly.opacity(0.7)))

        // Head, snout, nose.
        dog.fill(Path(ellipseIn: CGRect(x: 62, y: h - 45, width: 23, height: 22)), with: .color(Palette.coat))
        dog.fill(Path(roundedRect: CGRect(x: 76, y: h - 35, width: 18, height: 10), cornerRadius: 5),
                 with: .color(Palette.coat))
        dog.fill(Path(ellipseIn: CGRect(x: 89.5, y: h - 35.5, width: 5.5, height: 5)), with: .color(Palette.ink))

        // Eye with a highlight.
        dog.fill(Path(ellipseIn: CGRect(x: 74.5, y: h - 40.5, width: 5.2, height: 5.6)), with: .color(Palette.ink))
        dog.fill(Path(ellipseIn: CGRect(x: 76.3, y: h - 39.6, width: 1.9, height: 1.9)), with: .color(.white))

        // Big floppy ear, pivoting at the top of the head.
        var ear = dog
        ear.translateBy(x: 68, y: h - 42)
        ear.rotate(by: pose.ear)
        ear.fill(Path(roundedRect: CGRect(x: -5, y: -1, width: 11, height: 19), cornerRadius: 5.5),
                 with: .color(Palette.ear))
    }
}
