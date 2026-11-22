import AppKit

/// The dog's brain and his stage: a full-width transparent strip resting on the Dock.
/// Behaviour is goose-like: frantic sprints, little trots, wagging pauses, and a nap
/// on the Dock edge when nobody has touched the Mac for a while.
@MainActor
final class StageController: NSObject {
    let dog = DogModel()
    var isVisible: Bool { dog.isVisible }

    private var panel: StagePanel?
    private var dogView: DogView?
    private var restTask: Task<Void, Never>?
    private var idleTimer: Timer?
    private let napAfter: TimeInterval = 120

    func start() {
        let panel = StagePanel(size: CGSize(width: 800, height: DogView.height))
        let view = DogView(frame: CGRect(origin: .zero, size: panel.frame.size))
        view.onBoop = { [weak self] in self?.boop() }
        panel.contentView = view
        self.panel = panel
        dogView = view
        dog.onChange = { [weak self] in self?.render() }

        layoutStrip()
        render()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        rest(for: 1.5)
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIdle() }
        }
        idleTimer?.tolerance = 2

        // The strip covers the bottom of other windows, so it ignores the mouse unless the
        // cursor is actually over the dog. Checked 8×/s: cheap, and needs no permission.
        panel.ignoresMouseEvents = true
        mouseTimer = Timer.scheduledTimer(withTimeInterval: 0.125, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMouseCapture() }
        }
        mouseTimer?.tolerance = 0.05
    }

    private var mouseTimer: Timer?

    private func updateMouseCapture() {
        guard let panel, let dogView, isVisible else { return }
        let mouse = NSEvent.mouseLocation
        let local = CGPoint(x: mouse.x - panel.frame.minX, y: mouse.y - panel.frame.minY)
        let overDog = dogView.dogFrame.contains(local)
        if panel.ignoresMouseEvents == overDog { panel.ignoresMouseEvents = !overDog }
    }

    // MARK: Stage

    /// The strip spans the primary screen just above the Dock (or the bottom edge when
    /// the Dock is hidden), dipping slightly below so sleeping paws can dangle over it.
    private func layoutStrip() {
        guard let screen = NSScreen.screens.first, let panel else { return }
        let visible = screen.visibleFrame
        panel.setFrame(CGRect(x: visible.minX, y: visible.minY - DogView.hang,
                              width: visible.width, height: DogView.height), display: false)
        dogView?.frame = CGRect(origin: .zero, size: panel.frame.size)
        dogView?.clampIntoRange()
    }

    @objc private func screensChanged() { layoutStrip() }

    private func render() {
        dogView?.show(dog.pose)
        dogView?.face(right: dog.facingRight, profile: dog.pose != .sleep)
    }

    // MARK: Behaviour

    private func rest(for seconds: Double) {
        restTask?.cancel()
        restTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, self.isVisible, !self.dog.isAsleep else { return }
            self.decide()
        }
    }

    /// Goose rules: usually a mad dash, sometimes a trot, sometimes just standing around.
    private func decide() {
        guard let view = dogView else { return }
        let roll = Double.random(in: 0..<1)
        if roll < 0.55 {
            go(to: pickTarget(view, distance: .random(in: 250...700)), gait: .run, speed: .random(in: 300...420))
        } else if roll < 0.85 {
            go(to: pickTarget(view, distance: .random(in: 90...260)), gait: .trot, speed: 75)
        } else {
            rest(for: .random(in: 3...7))
        }
    }

    private func pickTarget(_ view: DogView, distance: CGFloat) -> CGFloat {
        let x = view.currentX
        let r = view.range
        let canGoRight = x + distance <= r.upperBound
        let canGoLeft = x - distance >= r.lowerBound
        let right = canGoRight && (!canGoLeft || Bool.random())
        return right ? x + distance : x - distance
    }

    private func go(to x: CGFloat, gait: DogModel.Gait, speed: CGFloat) {
        guard let view = dogView else { return }
        restTask?.cancel()
        dog.facingRight = x > view.currentX
        dog.gait = gait
        view.move(to: x, speed: speed, skid: gait == .run) { [weak self] in
            guard let self else { return }
            self.dog.gait = .still
            self.rest(for: .random(in: 1.5...6))
        }
    }

    // MARK: Napping

    /// Reads the system's idle time, which needs no permission and sees no content.
    private func checkIdle() {
        guard isVisible else { return }
        let anyInput = CGEventType(rawValue: ~0)!
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        if !dog.isAsleep, idle >= napAfter {
            fallAsleep()
        } else if dog.isAsleep, idle < 5 {
            wake()
        }
    }

    private func fallAsleep() {
        restTask?.cancel()
        dogView?.stop()
        dog.gait = .still
        dog.isAsleep = true
    }

    private func wake() {
        dog.isAsleep = false
        dogView?.hop()
        rest(for: 2)
    }

    func boop() {
        if dog.isAsleep { wake() } else { dogView?.hop() }
    }

    // MARK: Menu actions

    func callToCursor() {
        if !isVisible { toggleVisible() }
        dog.isAsleep = false
        let target = NSEvent.mouseLocation.x - (panel?.frame.minX ?? 0)
        go(to: target, gait: .run, speed: 460)
    }

    func toggleVisible() {
        dog.isVisible.toggle()
        if isVisible {
            panel?.orderFrontRegardless()
            rest(for: 1)
        } else {
            restTask?.cancel()
            dogView?.stop()
            dog.gait = .still
            panel?.orderOut(nil)
        }
    }
}
