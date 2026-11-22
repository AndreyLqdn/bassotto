import CoreGraphics
import Foundation

/// What the dog does, driven by what *you* do:
/// - while you use the Mac he lies on the Dock edge, facing you (awake, blinking);
/// - when you leave the mouse and keyboard alone he gets up and wanders the screen;
/// - the moment you're back he runs home and lies down again;
/// - after a long absence he falls asleep there.
///
/// Locomotion is Desktop Goose's, tick for tick (60 ticks/s): the heading eases 25% towards
/// the target each tick, velocity is capped then accelerated at accel/120, and the paws are
/// planted until they're 5 pt from home, then step there (+2 pt overshoot) with a cubic
/// ease. A dog trots, so the paws step in diagonal pairs instead of one at a time.
/// Coordinates are y-down screen points.
@MainActor
final class Brain {
    enum Mode { case resting, roaming, returning, sleeping }

    private static let tickRate: Double = 60
    // Goose speed tiers: walk 80 / run 200, acceleration 1300.
    private let walkSpeed: CGFloat = 80, runSpeed: CGFloat = 200, accel: CGFloat = 1300

    var home: CGPoint                         // where he lies, chin over the Dock edge
    var bounds: CGRect                        // where he may wander
    private(set) var mode: Mode = .resting
    private(set) var state: Doxie.State
    var blink = false

    private var velocity = CGPoint.zero
    private var target: CGPoint
    private var speed: CGFloat = 80
    private var stepTime: Double = 0.2
    private var pauseUntil: TimeInterval = 0
    private var sleepWhenHome = false
    private var now: TimeInterval = 0
    private var wagUntil: TimeInterval = 0
    private var nextWagRoll: TimeInterval = 0
    private var accumulator: Double = 0
    private var steps: [(from: CGPoint, dir: CGPoint, start: TimeInterval)?] = [nil, nil, nil, nil]
    private var stepping: Bool { steps.contains { $0 != nil } }

    init(home: CGPoint, bounds: CGRect) {
        self.home = home
        self.bounds = bounds
        target = home
        state = Doxie.State(pos: home, direction: 90)
        state.lying = 1
    }

    /// The pose to draw this frame.
    var pose: Doxie.State {
        var s = state
        s.eyesClosed = mode == .sleeping || (mode == .resting && blink)
        return s
    }

    /// Whether the frame loop needs to run (moving, or still settling into a pose).
    var isMoving: Bool {
        switch mode {
        case .returning: return true
        case .roaming: return now < pauseUntil ? stepping : true
        case .resting, .sleeping: return state.lying < 0.99 || abs(angleDelta(state.direction, 90)) > 1 || stepping
        }
    }

    var hitBox: CGRect { CGRect(x: state.pos.x - 45, y: state.pos.y - 40, width: 90, height: 62) }

    // MARK: Inputs

    func userWentIdle() {
        guard mode == .resting else { return }
        mode = .roaming
        speed = walkSpeed; stepTime = 0.2
        pickTarget()
    }

    func userCameBack() {
        sleepWhenHome = false
        switch mode {
        case .roaming: goHome()
        case .sleeping: mode = .resting
        case .resting, .returning: break
        }
    }

    func userLongGone() {
        switch mode {
        case .resting: mode = .sleeping
        case .roaming: sleepWhenHome = true; goHome()
        case .returning: sleepWhenHome = true
        case .sleeping: break
        }
    }

    func goForAWalk() {
        if mode == .sleeping { mode = .resting }
        userWentIdle()
    }

    private func goHome() {
        mode = .returning
        target = home
        speed = runSpeed; stepTime = 0.2         // the goose's Run tier keeps 0.2 s steps
    }

    // MARK: Simulation (fixed 60 Hz ticks, like the goose)

    func update(time: TimeInterval) {
        if now == 0 { now = time }
        accumulator += min(time - now, 0.25)
        now = time
        let dt = 1 / Self.tickRate
        while accumulator >= dt {
            accumulator -= dt
            tick(dt)
        }
    }

    private func tick(_ dt: Double) {
        let t = now - accumulator
        switch mode {
        case .resting, .sleeping:
            settle(towardsLying: true)
            solveFeet(time: t)
            return
        case .roaming where t < pauseUntil:
            velocity = .zero                       // the goose hard-stops while it pauses
            solveFeet(time: t)
            state.tongue *= 0.9
            wagTail(t)
            return
        default: break
        }
        settle(towardsLying: false)

        let pos = state.pos
        let to = CGPoint(x: target.x - pos.x, y: target.y - pos.y)
        let dist = hypot(to.x, to.y)
        if mode == .returning, dist < 5 { arriveHome(); return }
        if mode == .roaming, dist < 20 {
            pauseUntil = t + .random(in: 1...2)
            pickTarget()
            return
        }
        let dirToTarget = CGPoint(x: to.x / dist, y: to.y / dist)

        // Heading: lerp the facing vector 25% towards the target each tick.
        let f = Doxie.unit(state.direction)
        let v = CGPoint(x: f.x + (dirToTarget.x - f.x) * 0.25, y: f.y + (dirToTarget.y - f.y) * 0.25)
        state.direction = atan2(v.y, v.x) * 180 / .pi

        // Velocity: cap, then accelerate straight at the target, then move.
        let mag = hypot(velocity.x, velocity.y)
        if mag > speed { velocity.x *= speed / mag; velocity.y *= speed / mag }
        velocity.x += dirToTarget.x * accel / 120
        velocity.y += dirToTarget.y * accel / 120
        state.pos.x += velocity.x * CGFloat(dt)
        state.pos.y += velocity.y * CGFloat(dt)

        solveFeet(time: t)
        // Head low and forward when running; the tail wags while he trots.
        state.neckLerp += ((speed >= 200 ? 1 : 0) - state.neckLerp) * 0.075
        // Tongue out and flapping while he runs.
        state.tongue += ((speed >= 200 ? 1 : 0) - state.tongue) * 0.1
        state.tongueSwing = CGFloat(sin(t * 20))
        wagTail(t)
    }

    /// The tail wags in little bursts now and then, not all the time.
    private func wagTail(_ t: TimeInterval) {
        if t >= nextWagRoll {
            nextWagRoll = t + .random(in: 1.5...4)
            if Double.random(in: 0..<1) < 0.45 { wagUntil = t + .random(in: 0.8...1.8) }
        }
        let target: CGFloat = t < wagUntil ? CGFloat(sin(t * 16)) * 0.5 : 0
        state.wag += (target - state.wag) * 0.35
    }

    /// Ease into lying down (facing the viewer) or back up onto his feet.
    private func settle(towardsLying lying: Bool) {
        state.lying += ((lying ? 1 : 0) - state.lying) * 0.12
        state.neckLerp += (0 - state.neckLerp) * 0.075
        if lying {
            state.direction += angleDelta(state.direction, 90) * 0.15
            state.pos.x += (home.x - state.pos.x) * 0.2
            state.pos.y += (home.y - state.pos.y) * 0.2
            state.wag *= 0.9
        }
    }

    private func arriveHome() {
        velocity = .zero
        mode = sleepWhenHome ? .sleeping : .resting
        sleepWhenHome = false
        speed = walkSpeed; stepTime = 0.2
    }

    /// The goose's SolveFeet, run once for the chest pair and once for the hip pair:
    /// within a pair only one foot moves at a time (left checked first); a foot steps when
    /// it's more than 5 pt from home, landing 2 pt past it, with a cubic ease in-out.
    private func solveFeet(time t: TimeInterval) {
        for pair in [[0, 1], [2, 3]] {
            let homes = pair.map { Doxie.footHome($0, pos: state.pos, direction: state.direction) }
            if let i = pair.first(where: { steps[$0] != nil }), let step = steps[i] {
                let home = homes[pair.firstIndex(of: i)!]
                let landing = CGPoint(x: home.x + step.dir.x * 2, y: home.y + step.dir.y * 2)
                let p = (t - step.start) / stepTime
                if p >= 1 {
                    state.feet[i] = landing
                    steps[i] = nil
                } else {
                    let e = CGFloat(p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2)
                    state.feet[i] = CGPoint(x: step.from.x + (landing.x - step.from.x) * e,
                                            y: step.from.y + (landing.y - step.from.y) * e)
                }
                continue
            }
            for (n, i) in pair.enumerated() where hypot(state.feet[i].x - homes[n].x, state.feet[i].y - homes[n].y) > 5 {
                let d = CGPoint(x: homes[n].x - state.feet[i].x, y: homes[n].y - state.feet[i].y)
                let l = max(0.001, hypot(d.x, d.y))
                steps[i] = (state.feet[i], CGPoint(x: d.x / l, y: d.y / l), t)
                break
            }
        }
    }

    /// The goose wanders to a random point, but never more than a 1–6 s walk away.
    private func pickTarget() {
        var p = CGPoint(x: .random(in: bounds.minX...bounds.maxX), y: .random(in: bounds.minY...bounds.maxY))
        let reach = walkSpeed * .random(in: 1...6)
        let d = distance(p, state.pos)
        if d > reach {
            p = CGPoint(x: state.pos.x + (p.x - state.pos.x) / d * reach, y: state.pos.y + (p.y - state.pos.y) / d * reach)
        }
        target = p
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private func angleDelta(_ from: CGFloat, _ to: CGFloat) -> CGFloat {
        var d = (to - from).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }
}
