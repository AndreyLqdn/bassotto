import AppKit
import QuartzCore

/// The live dog: a full-screen, y-down layer tree. Each frame his shapes are written
/// into a pool of CAShapeLayers and the window server draws them. The sleeping Zzz and
/// the hop are pure Core Animation, so they cost the app nothing.
final class DoxieView: NSView {
    var onBoop: () -> Void = {}
    static let scale: CGFloat = 0.8

    private let dog = CALayer()
    private var pool: [CAShapeLayer] = []
    private var zzz: [CATextLayer] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .clear
        layer?.isGeometryFlipped = true             // y grows downwards, like the brain's coordinates
        dog.frame = bounds
        layer?.addSublayer(dog)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        dog.frame = bounds
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onBoop() }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        pool.forEach { $0.contentsScale = scale }
        zzz.forEach { $0.contentsScale = scale }
    }

    func render(_ pose: Doxie.Pose, at origin: CGPoint, facingRight: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var canvas = LayerCanvas(view: self)
        Doxie.draw(&canvas, pose, at: origin, facingRight: facingRight, scale: Self.scale)
        for layer in pool[canvas.used...] where !layer.isHidden { layer.isHidden = true }
        CATransaction.commit()
    }

    fileprivate func shape(_ i: Int) -> CAShapeLayer {
        while pool.count <= i {
            let l = CAShapeLayer()
            l.lineCap = .round
            l.lineJoin = .round
            l.contentsScale = window?.backingScaleFactor ?? 2
            dog.addSublayer(l)
            pool.append(l)
        }
        return pool[i]
    }

    // MARK: Effects (run by Core Animation)

    func hop() {
        let jump = CASpringAnimation(keyPath: "transform.translation.y")
        jump.fromValue = -14
        jump.toValue = 0
        jump.damping = 9
        jump.initialVelocity = 2
        jump.duration = jump.settlingDuration
        dog.add(jump, forKey: "hop")
    }

    /// Three Zs drifting up from his head while he sleeps.
    func showZzz(at head: CGPoint?) {
        zzz.forEach { $0.removeFromSuperlayer() }
        zzz.removeAll()
        guard let head else { return }
        for i in 0..<3 {
            let z = CATextLayer()
            z.string = "z"
            z.font = NSFont.systemFont(ofSize: 16, weight: .black)
            z.fontSize = 16
            z.foregroundColor = .white
            z.shadowColor = Doxie.Palette.cream.outline
            z.shadowOpacity = 1
            z.shadowRadius = 0.8
            z.shadowOffset = .zero
            z.alignmentMode = .center
            z.contentsScale = window?.backingScaleFactor ?? 2
            z.bounds = CGRect(x: 0, y: 0, width: 20, height: 22)
            z.position = head
            z.opacity = 0
            layer?.addSublayer(z)
            zzz.append(z)

            let rise = CABasicAnimation(keyPath: "position")
            rise.fromValue = NSValue(point: head)
            rise.toValue = NSValue(point: CGPoint(x: head.x + 26, y: head.y - 38))
            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = 0.6; grow.toValue = 1.25
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 1, 0]; fade.keyTimes = [0, 0.15, 0.7, 1]
            let group = CAAnimationGroup()
            group.animations = [rise, grow, fade]
            group.duration = 3
            group.repeatCount = .infinity
            group.beginTime = CACurrentMediaTime() + Double(i)
            z.add(group, forKey: "zzz")
        }
    }
}

/// Paints into the view's shape-layer pool, one layer per stroke or fill, in order.
@MainActor
private struct LayerCanvas: @MainActor DoxieCanvas {
    let view: DoxieView
    var used = 0

    mutating func stroke(_ path: CGPath, _ color: CGColor, width: CGFloat) {
        let l = view.shape(used); used += 1
        l.path = path; l.fillColor = nil; l.strokeColor = color; l.lineWidth = width
        if l.isHidden { l.isHidden = false }
    }

    mutating func fill(_ path: CGPath, _ color: CGColor) {
        let l = view.shape(used); used += 1
        l.path = path; l.fillColor = color; l.strokeColor = nil; l.lineWidth = 0
        if l.isHidden { l.isHidden = false }
    }
}
