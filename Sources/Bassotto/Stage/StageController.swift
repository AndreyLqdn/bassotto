import AppKit
import Observation
import QuartzCore

/// Runs the dog: a small transparent window that follows him anywhere on the screen,
/// a display link that only ticks while he's moving, and the menu actions.
@MainActor
@Observable
final class StageController: NSObject {
    private(set) var isVisible = true
    var mischief = true { didSet { brain?.mischief = mischief } }

    @ObservationIgnored private var panel: StagePanel?
    @ObservationIgnored private var view: DoxieView?
    @ObservationIgnored private var brain: Brain?
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var timers: [Timer] = []
    @ObservationIgnored private let napAfter: TimeInterval = 120

    func start() {
        let brain = Brain(bounds: roamBounds())
        brain.cursor = { [weak self] in self?.cursorInScreenSpace() ?? .zero }
        brain.moveCursor = { [weak self] p in self?.warpCursor(to: p) }
        self.brain = brain

        let panel = StagePanel(size: CGSize(width: 800, height: 600))
        let view = DoxieView(frame: CGRect(origin: .zero, size: panel.frame.size))
        if let screen = NSScreen.screens.first {
            panel.setFrame(screen.frame, display: false)
            view.frame = CGRect(origin: .zero, size: screen.frame.size)
        }
        view.onBoop = { [weak self] in self?.brain?.boop(); self?.wakeUp() }
        panel.contentView = view
        panel.ignoresMouseEvents = true
        self.panel = panel
        self.view = view
        render()
        panel.orderFrontRegardless()
        wakeUp()

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        every(5) { $0.checkIdle() }
        every(0.125) { $0.updateMouseCapture() }
        // While he stands around, look back now and then to start the next adventure.
        every(0.5) { $0.wakeUpIfIdleTaskDue() }
    }

    // MARK: Frame loop

    /// Starts the display link (60 fps) if it isn't running.
    private func wakeUp() {
        guard link == nil, isVisible, let screen = panel?.screen ?? NSScreen.screens.first else { return }
        let link = screen.displayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard let brain else { return }
        brain.update(time: link.timestamp)
        render()
        if !brain.isAnimating {           // standing still or asleep: stop redrawing
            link.invalidate()
            self.link = nil
        }
    }

    private func wakeUpIfIdleTaskDue() {
        guard link == nil, isVisible, let brain, !brain.isAsleep else { return }
        wakeUp()                          // the brain decides on its next task in update()
    }

    /// The window covers the whole screen and never moves; the dog's shape layers are
    /// updated in place and the window server does the drawing.
    private func render() {
        guard let brain, let view else { return }
        view.render(brain.pose, bubble: brain.bubble)
        // Walking is fine at 30 fps; dashes and chases get the full 60.
        let fast = brain.isFast
        let range = fast ? CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
                         : CAFrameRateRange(minimum: 24, maximum: 30, preferred: 30)
        if link?.preferredFrameRateRange != range { link?.preferredFrameRateRange = range }
    }

    // MARK: Screen & cursor

    /// The primary screen in y-down coordinates, kept clear of the menu bar.
    private func roamBounds() -> CGRect {
        guard let screen = NSScreen.screens.first else { return CGRect(x: 0, y: 0, width: 1440, height: 900) }
        let f = screen.frame, v = screen.visibleFrame
        let top = f.maxY - v.maxY
        return CGRect(x: f.minX + 60, y: top + 70, width: f.width - 120, height: v.height - 90)
    }

    @objc private func screensChanged() {
        brain?.bounds = roamBounds()
        if let screen = NSScreen.screens.first {
            panel?.setFrame(screen.frame, display: false)
            view?.frame = CGRect(origin: .zero, size: screen.frame.size)
        }
    }

    private func cursorInScreenSpace() -> CGPoint {
        let m = NSEvent.mouseLocation
        let h = NSScreen.screens.first?.frame.maxY ?? 0
        return CGPoint(x: m.x, y: h - m.y)
    }

    private func warpCursor(to p: CGPoint) {
        // Global display coordinates are y-down from the top of the primary screen.
        CGWarpMouseCursorPosition(p)
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    /// The window only takes clicks when the cursor is over the dog.
    private func updateMouseCapture() {
        guard let panel, let brain, isVisible else { return }
        let c = cursorInScreenSpace()
        let p = brain.pose.pos
        let overDog = abs(c.x - p.x) < 40 && c.y > p.y - 40 && c.y < p.y + 12
        if panel.ignoresMouseEvents == overDog { panel.ignoresMouseEvents = !overDog }
    }

    // MARK: Napping

    /// Uses the system idle time: no permission needed, no content seen.
    private func checkIdle() {
        guard isVisible, let brain else { return }
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        if !brain.isAsleep, idle >= napAfter {
            brain.fallAsleep()
            wakeUp()                      // one more frame to draw him lying down
        } else if brain.isAsleep, idle < 5 {
            brain.wake()
            wakeUp()
        }
    }

    // MARK: Menu actions

    func callToCursor() {
        if !isVisible { toggleVisible() }
        brain?.comeHere()
        wakeUp()
    }

    func toggleVisible() {
        isVisible.toggle()
        if isVisible {
            panel?.orderFrontRegardless()
            wakeUp()
        } else {
            link?.invalidate(); link = nil
            panel?.orderOut(nil)
        }
    }

    private func every(_ seconds: TimeInterval, _ body: @escaping @MainActor (StageController) -> Void) {
        let t = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { if let self { body(self) } }
        }
        t.tolerance = seconds * 0.3
        timers.append(t)
    }
}
