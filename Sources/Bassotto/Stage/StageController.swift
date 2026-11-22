import AppKit
import QuartzCore
import SwiftUI

/// Owns the stage panel and moves the dog along the ground (the top of the Dock,
/// or the bottom of the screen when the Dock is hidden).
///
/// The display link only runs while he walks, so a resting dog costs ~0% CPU.
@MainActor
final class StageController: NSObject {
    let dog = DogModel()
    var isVisible: Bool { dog.isVisible }

    private let size = StageMetrics.size
    private let walkSpeed: CGFloat = 70     // points per second
    private let runSpeed: CGFloat = 220

    private var panel: StagePanel?
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var x: CGFloat = 0
    private var targetX: CGFloat = 0
    private var speed: CGFloat = 70
    private var restTask: Task<Void, Never>?

    func start() {
        let panel = StagePanel(size: size)
        panel.contentView = StageHostingView(rootView: DogView(dog: dog))
        self.panel = panel

        x = ground.minX + (ground.maxX - ground.minX) * 0.3
        targetX = x
        place()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        rest(for: 1.5)
    }

    // MARK: Menu actions

    func callToCursor() {
        if !isVisible { toggleVisible() }
        walk(to: NSEvent.mouseLocation.x - size.width / 2, speed: runSpeed)
    }

    func toggleVisible() {
        dog.isVisible.toggle()
        if isVisible {
            panel?.orderFrontRegardless()
            rest(for: 1)
        } else {
            stopWalking()
            restTask?.cancel()
            panel?.orderOut(nil)
        }
    }

    // MARK: Ground

    /// The walkable line: primary screen, standing on top of the Dock when it's at the bottom.
    private var ground: (minX: CGFloat, maxX: CGFloat, y: CGFloat) {
        let screen = NSScreen.screens.first ?? NSScreen.main
        let frame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        return (frame.minX, frame.maxX - size.width, frame.minY)
    }

    private func place() {
        let g = ground
        x = min(max(x, g.minX), g.maxX)
        panel?.setFrameOrigin(CGPoint(x: x, y: g.y))
    }

    @objc private func screensChanged() {
        targetX = min(max(targetX, ground.minX), ground.maxX)
        place()
    }

    // MARK: Behaviour

    private func rest(for seconds: Double) {
        restTask?.cancel()
        restTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, self.isVisible else { return }
            self.wander()
        }
    }

    private func wander() {
        let g = ground
        var next = CGFloat.random(in: g.minX...g.maxX)
        if abs(next - x) < 120 { next = x < (g.minX + g.maxX) / 2 ? x + 240 : x - 240 }
        walk(to: next, speed: walkSpeed)
    }

    private func walk(to destination: CGFloat, speed: CGFloat) {
        restTask?.cancel()
        targetX = min(max(destination, ground.minX), ground.maxX)
        self.speed = speed
        dog.facingRight = targetX > x
        dog.isWalking = true

        if displayLink == nil, let screen = panel?.screen ?? NSScreen.screens.first {
            lastTimestamp = nil
            let link = screen.displayLink(target: self, selector: #selector(tick(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 30, preferred: 30)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        defer { lastTimestamp = now }
        guard let last = lastTimestamp else { return }

        let step = speed * CGFloat(now - last)
        let remaining = targetX - x
        if abs(remaining) <= step {
            x = targetX
            place()
            arrived()
        } else {
            x += remaining > 0 ? step : -step
            place()
        }
    }

    private func arrived() {
        stopWalking()
        // Mostly short pauses, sometimes a proper nap.
        rest(for: Bool.random() ? .random(in: 3...8) : .random(in: 12...30))
    }

    private func stopWalking() {
        displayLink?.invalidate()
        displayLink = nil
        dog.isWalking = false
    }
}
