import CoreGraphics
import Foundation

/// Goose-style physics and behaviour. Works in screen points with y growing downwards.
/// The body steers towards a target with acceleration and smooth turning; each paw stays
/// planted until the body has moved on, then takes a quick step. That stepping is what
/// makes him waddle when walking and scurry frantically when running.
@MainActor
final class Brain {
    enum Task: Equatable {
        case idle(until: TimeInterval)
        case walk(to: CGPoint)
        case zoom(to: CGPoint)
        case chaseCursor
        case dragCursor(until: TimeInterval, away: CGPoint)
        case sleep
    }

    struct Gait { let speed: CGFloat, accel: CGFloat, stepTime: Double, stepDist: CGFloat, lift: CGFloat }
    static let walkGait = Gait(speed: 80, accel: 900, stepTime: 0.17, stepDist: 9, lift: 3.5)
    static let runGait = Gait(speed: 300, accel: 2200, stepTime: 0.085, stepDist: 7, lift: 5)
    static let chargeGait = Gait(speed: 420, accel: 3000, stepTime: 0.07, stepDist: 7, lift: 5.5)

    var bounds: CGRect                       // where he may roam (screen, y down)
    var mischief = true                      // allowed to steal the cursor
    private(set) var pose: Doxie.Pose
    private(set) var task: Task = .idle(until: 0)
    private(set) var bubble: String?         // "woof!" / "z z z"

    private var vel = CGPoint.zero
    private var steps: [(from: CGPoint, to: CGPoint, start: TimeInterval)?] = [nil, nil, nil, nil]
    private var now: TimeInterval = 0
    private var bubbleUntil: TimeInterval = 0
    private var wagUntil: TimeInterval = 0

    /// Called when he grabs the cursor and every frame while dragging it.
    var moveCursor: ((CGPoint) -> Void)?
    var cursor: () -> CGPoint = { .zero }

    init(bounds: CGRect) {
        self.bounds = bounds
        let start = CGPoint(x: bounds.midX, y: bounds.maxY - 40)
        pose = Doxie.Pose(pos: start, heading: 0,
                          feet: (0..<4).map { Doxie.restingFoot($0, pos: start, heading: 0) })
    }

    /// Whether anything is animating (so the display link can stop when he's still).
    var isAnimating: Bool {
        if case .idle = task { return now < wagUntil || now < bubbleUntil || steps.contains { $0 != nil } }
        if case .sleep = task { return false }
        return true
    }

    var isAsleep: Bool { task == .sleep }

    /// Sprinting or chasing: worth drawing at 60 fps.
    var isFast: Bool {
        switch task {
        case .zoom, .chaseCursor: true
        default: false
        }
    }

    // MARK: Commands

    func comeHere() { wake(); task = .chaseCursor }
    func boop() {
        if isAsleep { wake(); return }
        bark()
        wagUntil = now + 1.5
    }
    func fallAsleep() {
        task = .sleep
        vel = .zero
        bubble = "z z z"
    }
    func wake() {
        guard isAsleep else { return }
        task = .idle(until: now + 1)
        bubble = nil
        bark()
    }

    private func bark() {
        bubble = "woof!"
        bubbleUntil = now + 0.9
        pose.mouthOpen = true
    }

    // MARK: Simulation

    func update(time: TimeInterval) {
        let dt = min(time - now, 1.0 / 20)
        now = time
        if bubbleUntil > 0, now > bubbleUntil, !isAsleep { bubble = nil; bubbleUntil = 0; pose.mouthOpen = false }

        var target: CGPoint?
        var gait = Self.walkGait
        switch task {
        case .idle(let until):
            if now >= until { decide() }
        case .walk(let to):
            target = to
        case .zoom(let to):
            target = to; gait = Self.runGait
        case .chaseCursor:
            target = cursor(); gait = Self.chargeGait
            if distance(Doxie.mouth(pose), cursor()) < 14 { grabCursor() }
        case .dragCursor(let until, let away):
            target = away; gait = Self.walkGait
            moveCursor?(Doxie.mouth(pose))
            if now >= until { task = .idle(until: now + 1); bark() }
        case .sleep:
            pose.crouch = min(1, pose.crouch + CGFloat(dt) * 2)
            pose.eyesClosed = true
            return
        }
        pose.crouch = max(0, pose.crouch - CGFloat(dt) * 3)
        pose.eyesClosed = false

        steer(towards: target, gait: gait, dt: dt)
        stepFeet(gait: gait)
        animateBody(gait: gait)

        if let target, distance(pose.pos, target) < 6, task != .chaseCursor {
            if case .dragCursor = task { return }
            vel = .zero
            task = .idle(until: now + .random(in: 0.8...3.5))
            if Double.random(in: 0..<1) < 0.3 { wagUntil = now + 1.2 }
            if Double.random(in: 0..<1) < 0.15 { bark() }
        }
    }

    /// Goose rules: mostly wander, sometimes zoomies, now and then go after the cursor.
    private func decide() {
        let roll = Double.random(in: 0..<1)
        if mischief, roll < 0.06 {
            task = .chaseCursor
        } else if roll < 0.35 {
            task = .zoom(to: randomPoint(minDistance: 400))
        } else {
            task = .walk(to: randomPoint(minDistance: 120, maxDistance: 420))
        }
    }

    private func grabCursor() {
        bark()
        let away = CGPoint(x: pose.pos.x - cos(pose.heading) * 260, y: pose.pos.y - sin(pose.heading) * 160)
        task = .dragCursor(until: now + 1.6, away: clamp(away))
    }

    private func steer(towards target: CGPoint?, gait: Gait, dt: Double) {
        var desired = CGPoint.zero
        if let target {
            let to = CGPoint(x: target.x - pose.pos.x, y: target.y - pose.pos.y)
            let dist = hypot(to.x, to.y)
            if dist > 0.5 {
                let speed = min(gait.speed, dist * 4)             // ease into the stop
                desired = CGPoint(x: to.x / dist * speed, y: to.y / dist * speed)
            }
        }
        // Accelerate towards the desired velocity.
        let dv = CGPoint(x: desired.x - vel.x, y: desired.y - vel.y)
        let dvLen = hypot(dv.x, dv.y), maxDv = gait.accel * CGFloat(dt)
        let k = dvLen > maxDv ? maxDv / dvLen : 1
        vel.x += dv.x * k; vel.y += dv.y * k
        pose.pos.x += vel.x * CGFloat(dt); pose.pos.y += vel.y * CGFloat(dt)
        pose.pos = clamp(pose.pos)

        // Turn smoothly to face where he's going (dragging the cursor: walk backwards).
        let speed = hypot(vel.x, vel.y)
        if speed > 12 {
            var want = atan2(vel.y, vel.x)
            if case .dragCursor = task { want += .pi }
            var delta = want - pose.heading
            while delta > .pi { delta -= 2 * .pi }
            while delta < -.pi { delta += 2 * .pi }
            pose.heading += delta * min(1, CGFloat(dt) * 12)
        }
    }

    private func stepFeet(gait: Gait) {
        let lead = CGPoint(x: vel.x * 0.06, y: vel.y * 0.06)          // feet land a bit ahead
        let center = CGPoint(x: pose.pos.x + lead.x, y: pose.pos.y + lead.y)
        for i in 0..<4 {
            if let step = steps[i] {
                let t = min(1, (now - step.start) / gait.stepTime)
                let e = CGFloat(t * t * (3 - 2 * t))
                pose.feet[i] = CGPoint(x: step.from.x + (step.to.x - step.from.x) * e,
                                       y: step.from.y + (step.to.y - step.from.y) * e)
                pose.footLift[i] = sin(CGFloat(t) * .pi) * gait.lift
                if t >= 1 { steps[i] = nil; pose.footLift[i] = 0 }
                continue
            }
            let ideal = Doxie.restingFoot(i, pos: center, heading: pose.heading)
            // Diagonal pairs alternate: a foot waits while its neighbours are mid-step.
            let neighbours = i < 2 ? [1 - i, i + 2] : [5 - i, i - 2]
            if distance(pose.feet[i], ideal) > gait.stepDist, neighbours.allSatisfy({ steps[$0] == nil }) {
                steps[i] = (pose.feet[i], ideal, now)
            }
        }
    }

    private func animateBody(gait: Gait) {
        let speed = hypot(vel.x, vel.y)
        pose.bob = pose.footLift.reduce(0, +) * 0.25
        pose.earFlap = min(1, max(0, (speed - 90) / 200))
        if now < wagUntil {
            pose.wag = CGFloat(sin(now * 22)) * 0.6
        } else {
            pose.wag = speed > 150 ? CGFloat(sin(now * 18)) * 0.15 : pose.wag * 0.9
        }
    }

    // MARK: Helpers

    private func randomPoint(minDistance: CGFloat, maxDistance: CGFloat = .greatestFiniteMagnitude) -> CGPoint {
        for _ in 0..<12 {
            let p = CGPoint(x: .random(in: bounds.minX...bounds.maxX), y: .random(in: bounds.minY...bounds.maxY))
            let d = distance(p, pose.pos)
            if d >= minDistance, d <= maxDistance { return p }
        }
        return CGPoint(x: .random(in: bounds.minX...bounds.maxX), y: .random(in: bounds.minY...bounds.maxY))
    }

    private func clamp(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, bounds.minX), bounds.maxX), y: min(max(p.y, bounds.minY), bounds.maxY))
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}
