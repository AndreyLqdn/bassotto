import AppKit
import Observation
import QuartzCore

/// Runs the dog: a full-screen transparent window that never moves, a frame loop that
/// only ticks while he's walking, and a 1 s check of how long you've been idle.
@MainActor
@Observable
final class StageController: NSObject {
    private(set) var isVisible = true

    /// After this long without keyboard/mouse input he goes for a walk.
    @ObservationIgnored private let roamAfter: TimeInterval = 20
    /// After this long he goes home and sleeps.
    @ObservationIgnored private let sleepAfter: TimeInterval = 600

    @ObservationIgnored private var panel: StagePanel?
    @ObservationIgnored private var view: DoxieView?
    @ObservationIgnored private var brain: Brain?
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var timers: [Timer] = []
    @ObservationIgnored private var shownMode: Brain.Mode?

    func start() {
        let (home, bounds) = layout()
        let brain = Brain(home: home, bounds: bounds)
        self.brain = brain

        let panel = StagePanel(size: CGSize(width: 800, height: 600))
        let view = DoxieView(frame: CGRect(origin: .zero, size: panel.frame.size))
        view.onBoop = { [weak self] in self?.boop() }
        panel.contentView = view
        panel.ignoresMouseEvents = true
        self.panel = panel
        self.view = view
        fitToScreen()
        render()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        every(1) { $0.checkIdle() }
        every(0.125) { $0.updateMouseCapture() }
        every(4) { $0.maybeBlink() }
    }

    // MARK: Layout

    /// Home is on the Dock's top edge, a little right of centre (the Dock is centred, so
    /// this is always on it). He may wander anywhere above the Dock, below the menu bar.
    private func layout() -> (home: CGPoint, bounds: CGRect) {
        guard let screen = NSScreen.screens.first else { return (.zero, .zero) }
        let f = screen.frame, v = screen.visibleFrame
        let dockTop = f.maxY - v.minY                     // y-down
        let menuBar = f.maxY - v.maxY
        // He lies facing you with his chin and front paws just over the Dock edge.
        let home = CGPoint(x: f.midX + 120, y: dockTop - 12 * DoxieView.scale)
        let bounds = CGRect(x: f.minX + 60, y: menuBar + 70, width: f.width - 120, height: dockTop - menuBar - 75)
        return (home, bounds)
    }

    private func fitToScreen() {
        guard let screen = NSScreen.screens.first else { return }
        panel?.setFrame(screen.frame, display: false)
        view?.frame = CGRect(origin: .zero, size: screen.frame.size)
    }

    @objc private func screensChanged() {
        let (home, bounds) = layout()
        brain?.home = home
        brain?.bounds = bounds
        fitToScreen()
        render()
    }

    // MARK: Frame loop

    private func startLoop() {
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
        if !brain.isMoving {
            link.invalidate()
            self.link = nil
        }
    }

    private func render() {
        guard let brain, let view else { return }
        view.render(brain.pose)
        if brain.mode != shownMode {
            if shownMode == .returning, brain.mode == .resting { view.hop() }   // plops down home
            let head = CGPoint(x: brain.home.x + 14, y: brain.home.y - 4)
            view.showZzz(at: brain.mode == .sleeping ? head : nil)
            shownMode = brain.mode
        }
    }

    // MARK: Idle detection (system counter: no permission, no content)

    private func checkIdle() {
        guard isVisible, let brain else { return }
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        if idle >= sleepAfter {
            brain.userLongGone()
        } else if idle >= roamAfter {
            brain.userWentIdle()
        } else if idle < 1.5 {
            brain.userCameBack()
        }
        if brain.isMoving { startLoop() } else { render() }
    }

    private func maybeBlink() {
        guard isVisible, let brain, brain.mode == .resting, Bool.random() else { return }
        brain.blink = true; render()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            self?.brain?.blink = false; self?.render()
        }
    }

    /// The window only takes clicks when the cursor is over the dog.
    private func updateMouseCapture() {
        guard let panel, let brain, isVisible else { return }
        let m = NSEvent.mouseLocation
        let c = CGPoint(x: m.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - m.y)
        let box = brain.hitBox, p = brain.state.pos, k = DoxieView.scale
        let scaled = CGRect(x: p.x + (box.minX - p.x) * k, y: p.y + (box.minY - p.y) * k,
                            width: box.width * k, height: box.height * k)
        let over = scaled.contains(c)
        if panel.ignoresMouseEvents == over { panel.ignoresMouseEvents = !over }
    }

    private func boop() {
        guard let brain else { return }
        if brain.mode == .sleeping { brain.userCameBack() }
        view?.hop()
        render()
    }

    // MARK: Menu actions

    func goForAWalk() {
        if !isVisible { toggleVisible() }
        brain?.goForAWalk()
        startLoop()
    }

    func toggleVisible() {
        isVisible.toggle()
        if isVisible {
            panel?.orderFrontRegardless()
            render()
        } else {
            link?.invalidate(); link = nil
            panel?.orderOut(nil)
        }
    }

    private func every(_ seconds: TimeInterval, _ body: @escaping @MainActor (StageController) -> Void) {
        let t = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { if let self { body(self) } }
        }
        t.tolerance = seconds * 0.25
        timers.append(t)
    }
}
