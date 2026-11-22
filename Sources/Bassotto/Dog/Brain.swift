import CoreGraphics
import Foundation

/// What the dog does, driven by what *you* do:
/// - while you use the Mac he rests on the Dock (awake, blinking);
/// - when you leave the mouse and keyboard alone (reading, watching a video) he gets up
///   and waddles around the screen;
/// - the moment you're back he runs home to the Dock and lies down again;
/// - after a long absence he falls asleep on the Dock.
/// Coordinates are screen points with y growing downwards.
@MainActor
final class Brain {
    enum Mode { case resting, roaming, returning, sleeping }

    // Desktop Goose's feel: walk 80 pt/s, accel 1300; we hurry home a bit faster.
    private let walkSpeed: CGFloat = 80, runSpeed: CGFloat = 210, accel: CGFloat = 1300

    var home: CGPoint                         // his spot on the Dock edge
    var bounds: CGRect                        // where he may wander
    private(set) var mode: Mode = .resting
    private(set) var pos: CGPoint
    private(set) var facingRight = true
    private(set) var blink = false

    private var vel = CGPoint.zero
    private var phase: CGFloat = 0
    private var target: CGPoint?
    private var pauseUntil: TimeInterval = 0
    private var sleepWhenHome = false
    private var now: TimeInterval = 0

    init(home: CGPoint, bounds: CGRect) {
        self.home = home
        self.bounds = bounds
        pos = home
    }

    var pose: Doxie.Pose {
        switch mode {
        case .resting: .rest(blink: blink, breath: 0)
        case .sleeping: .sleep(breath: 0)
        case .roaming, .returning:
            .walk(phase: phase, speed: mode == .returning ? 1 : min(1, hypot(vel.x, vel.y) / runSpeed))
        }
    }

    /// Whether the frame loop needs to run.
    var isMoving: Bool {
        switch mode {
        case .returning: true
        case .roaming: now >= pauseUntil
        case .resting, .sleeping: false
        }
    }

    /// Clickable area around him, in screen space (y down).
    var hitBox: CGRect {
        switch mode {
        case .resting, .sleeping: CGRect(x: pos.x - 46, y: pos.y - 56, width: 92, height: 62)
        case .roaming, .returning: CGRect(x: pos.x - 50, y: pos.y - 62, width: 100, height: 66)
        }
    }

    // MARK: Inputs

    /// You stopped touching the Mac: time for a walk.
    func userWentIdle() {
        guard mode == .resting else { return }
        mode = .roaming
        pauseUntil = 0
        pickTarget()
    }

    /// You're back: hurry home and lie down (not asleep).
    func userCameBack() {
        sleepWhenHome = false
        switch mode {
        case .roaming: mode = .returning; target = home
        case .sleeping: mode = .resting
        case .resting, .returning: break
        }
    }

    /// You've been away a long time: go home and sleep.
    func userLongGone() {
        switch mode {
        case .resting: mode = .sleeping
        case .roaming: sleepWhenHome = true; mode = .returning; target = home
        case .returning: sleepWhenHome = true
        case .sleeping: break
        }
    }

    func setBlink(_ closed: Bool) { blink = closed }

    /// "Go for a walk" from the menu.
    func goForAWalk() {
        if mode == .sleeping { mode = .resting }
        userWentIdle()
    }

    // MARK: Simulation

    func update(time: TimeInterval) {
        let dt = CGFloat(min(time - now, 1.0 / 20))
        now = time
        guard mode == .roaming || mode == .returning, let target else { return }
        if mode == .roaming, now < pauseUntil { return }

        let speedCap = mode == .returning ? runSpeed : walkSpeed
        let to = CGPoint(x: target.x - pos.x, y: target.y - pos.y)
        let dist = hypot(to.x, to.y)

        if dist < 5 { arrive(); return }

        // Accelerate straight at the target, capped, easing in over the last stretch.
        let cap = min(speedCap, max(30, dist * 3))
        vel.x += to.x / dist * accel * dt
        vel.y += to.y / dist * accel * dt
        let v = hypot(vel.x, vel.y)
        if v > cap { vel.x *= cap / v; vel.y *= cap / v }
        pos.x += vel.x * dt
        pos.y += vel.y * dt

        if vel.x > 6 { facingRight = true } else if vel.x < -6 { facingRight = false }
        // Feet cycle about every 0.4 s walking (one step per 0.2 s, like the goose), faster running.
        let cycle: CGFloat = mode == .returning ? 0.24 : 0.4
        phase += dt * 2 * .pi / cycle * min(1, hypot(vel.x, vel.y) / max(1, speedCap * 0.5))
    }

    private func arrive() {
        vel = .zero
        if mode == .returning {
            pos = home
            mode = sleepWhenHome ? .sleeping : .resting
            sleepWhenHome = false
            target = nil
        } else {
            pauseUntil = now + .random(in: 1...2.5)      // sniff around, then move on
            pickTarget()
        }
    }

    /// A random spot within a short walk (1–6 s), like the goose's wandering.
    private func pickTarget() {
        let reach = walkSpeed * .random(in: 1...6)
        let angle = CGFloat.random(in: 0..<(2 * .pi))
        var p = CGPoint(x: pos.x + cos(angle) * reach, y: pos.y + sin(angle) * reach)
        p.x = min(max(p.x, bounds.minX), bounds.maxX)
        p.y = min(max(p.y, bounds.minY), bounds.maxY)
        target = p
    }
}
