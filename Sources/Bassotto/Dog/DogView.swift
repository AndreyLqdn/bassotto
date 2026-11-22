import AppKit
import QuartzCore

/// Shows the dog as a Core Animation layer playing pre-rendered loops.
/// The window server runs the animation, so a breathing, sleeping dog costs ~0% CPU.
final class DogView: NSView {
    static let scale: CGFloat = 0.6
    static let spriteSize = CGSize(width: Kawaii.canvas.width * scale, height: Kawaii.canvas.height * scale)

    var onBoop: () -> Void = {}

    private let sprite = CALayer()
    private var sprites: DogSprites?
    private var shownPose: Kawaii.Pose?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .clear
        sprite.frame = CGRect(x: (frame.width - Self.spriteSize.width) / 2, y: 0,
                              width: Self.spriteSize.width, height: Self.spriteSize.height)
        sprite.contentsGravity = .resizeAspect
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.position = CGPoint(x: frame.width / 2, y: 0)
        layer?.addSublayer(sprite)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Clicks only count on the dog itself; everywhere else falls through.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return sprite.frame.insetBy(dx: 6, dy: 4).contains(local) ? self : nil
    }

    override func mouseDown(with event: NSEvent) { onBoop() }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let pixelScale = window?.backingScaleFactor ?? 2
        sprite.contentsScale = pixelScale
        sprites = DogSprites(scale: Self.scale, pixelScale: pixelScale)
        if let pose = shownPose { shownPose = nil; show(pose) }
    }

    /// Switches the looping animation to `pose`.
    @MainActor
    func show(_ pose: Kawaii.Pose) {
        guard pose != shownPose, let sprites else { shownPose = pose; return }
        shownPose = pose
        let loop = sprites.loop(pose)
        let play = CAKeyframeAnimation(keyPath: "contents")
        play.values = loop.frames
        play.duration = loop.duration
        play.calculationMode = .discrete
        play.repeatCount = .infinity
        play.isRemovedOnCompletion = false
        sprite.contents = loop.frames.first
        sprite.removeAnimation(forKey: "loop")
        sprite.add(play, forKey: "loop")
    }

    /// Mirrors the walk when he heads left. Rest and sleep always face the viewer.
    func face(right: Bool, walking: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sprite.transform = (walking && !right) ? CATransform3DMakeScale(-1, 1, 1) : CATransform3DIdentity
        CATransaction.commit()
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

    func setPaused(_ paused: Bool) {
        // Freezing the layer clock stops the window server from redrawing him.
        if paused {
            sprite.timeOffset = sprite.convertTime(CACurrentMediaTime(), from: nil)
            sprite.speed = 0
        } else if sprite.speed == 0 {
            let paused = sprite.timeOffset
            sprite.speed = 1
            sprite.timeOffset = 0
            sprite.beginTime = 0
            sprite.beginTime = sprite.convertTime(CACurrentMediaTime(), from: nil) - paused
        }
    }
}

enum StageMetrics {
    /// Room for the dog (120×67) plus a hop and the floating Zzz above him.
    static let size = CGSize(width: 130, height: 90)
}
