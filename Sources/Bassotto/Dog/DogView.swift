import AppKit
import QuartzCore

/// A full-width strip along the Dock. The dog is one Core Animation layer inside it:
/// his pose loops and his movement across the strip are both run by the window server,
/// so walking and sprinting cost the app almost nothing.
final class DogView: NSView {
    static let scale: CGFloat = 0.6
    static let spriteSize = CGSize(width: DogArt.canvas.width * scale, height: DogArt.canvas.height * scale)
    /// How far below the ground line the strip extends (paws dangling over the Dock edge).
    static let hang = (DogArt.canvas.height - DogArt.ground) * scale
    static let height = spriteSize.height + 18   // room to hop

    var onBoop: () -> Void = {}

    private let sprite = CALayer()
    private var sprites: DogSprites?
    private var shownPose: DogArt.Pose?
    private var moveToken = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .clear
        sprite.bounds = CGRect(origin: .zero, size: Self.spriteSize)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.position = CGPoint(x: frame.width * 0.3, y: 0)
        sprite.contentsGravity = .resizeAspect
        layer?.addSublayer(sprite)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// The clickable area: the dog himself, wherever he is mid-animation.
    var dogFrame: CGRect { (sprite.presentation() ?? sprite).frame.insetBy(dx: 14, dy: 6) }

    // Only the dog is clickable; the rest of the strip lets clicks fall through.
    override func hitTest(_ point: NSPoint) -> NSView? {
        dogFrame.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) { onBoop() }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let pixelScale = window?.backingScaleFactor ?? 2
        sprite.contentsScale = pixelScale
        sprites = DogSprites(scale: Self.scale, pixelScale: pixelScale)
        if let pose = shownPose { shownPose = nil; show(pose) }
    }

    // MARK: Pose

    @MainActor
    func show(_ pose: DogArt.Pose) {
        guard pose != shownPose, let sprites else { shownPose = pose; return }
        shownPose = pose
        let loop = sprites.loop(pose)
        let play = CAKeyframeAnimation(keyPath: "contents")
        play.values = loop.frames
        play.duration = loop.duration
        play.calculationMode = .discrete
        play.repeatCount = .infinity
        sprite.contents = loop.frames.first
        sprite.add(play, forKey: "loop")
    }

    func face(right: Bool, profile: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sprite.transform = (profile && !right) ? CATransform3DMakeScale(-1, 1, 1) : CATransform3DIdentity
        CATransaction.commit()
    }

    // MARK: Movement (run by the window server)

    /// Where he is right now, even mid-sprint.
    var currentX: CGFloat { (sprite.presentation() ?? sprite).position.x }

    var range: ClosedRange<CGFloat> {
        let half = Self.spriteSize.width / 2
        return half...(bounds.width - half)
    }

    /// Moves him to `x` at `speed` points per second, then calls `arrived` (unless interrupted).
    func move(to x: CGFloat, speed: CGFloat, skid: Bool, arrived: @escaping () -> Void) {
        let from = currentX
        let to = min(max(x, range.lowerBound), range.upperBound)
        moveToken += 1
        let token = moveToken

        let travel = CABasicAnimation(keyPath: "position.x")
        travel.fromValue = from
        travel.toValue = to
        travel.duration = max(Double(abs(to - from) / speed), 0.05)
        travel.timingFunction = CAMediaTimingFunction(name: .linear)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, token == self.moveToken else { return }
            if skid { self.skid(direction: to > from ? 1 : -1) }
            arrived()
        }
        sprite.position.x = to
        sprite.add(travel, forKey: "move")
        CATransaction.commit()
    }

    func stop() {
        moveToken += 1
        let x = currentX
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sprite.removeAnimation(forKey: "move")
        sprite.position.x = x
        CATransaction.commit()
    }

    /// A little overshoot and settle after a sprint, like brakes on a polished floor.
    private func skid(direction: CGFloat) {
        let settle = CASpringAnimation(keyPath: "position.x")
        settle.fromValue = sprite.position.x + direction * 10
        settle.toValue = sprite.position.x
        settle.damping = 11
        settle.duration = settle.settlingDuration
        sprite.add(settle, forKey: "skid")
    }

    func hop() {
        let jump = CASpringAnimation(keyPath: "position.y")
        jump.fromValue = 16
        jump.toValue = 0
        jump.damping = 9
        jump.initialVelocity = 2
        jump.duration = jump.settlingDuration
        sprite.add(jump, forKey: "hop")
    }

    /// Keeps him inside the strip after the screen changes size.
    func clampIntoRange() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sprite.position.x = min(max(sprite.position.x, range.lowerBound), range.upperBound)
        CATransaction.commit()
    }
}
