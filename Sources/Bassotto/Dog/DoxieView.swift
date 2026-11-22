import AppKit
import QuartzCore

/// The live dog: a full-screen, y-down layer tree. Each frame the dog's shapes are
/// written into a pool of CAShapeLayers; the window server rasterises and composites
/// them, so the app itself only does a little geometry per frame.
final class DoxieView: NSView {
    var onBoop: () -> Void = {}

    private let dog = CALayer()
    private var pool: [CAShapeLayer] = []
    private let bubble = CALayer()
    private let bubbleBackground = CAShapeLayer()
    private let bubbleText = CATextLayer()
    private var bubbleString: String?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .clear
        layer?.isGeometryFlipped = true             // y grows downwards, like the brain's coordinates
        layer?.addSublayer(dog)
        layer?.addSublayer(bubble)

        bubbleBackground.fillColor = CGColor(gray: 1, alpha: 0.95)
        bubbleBackground.strokeColor = Doxie.Palette.classic.outline
        bubbleBackground.lineWidth = 1.5
        bubbleText.font = NSFont.systemFont(ofSize: 12, weight: .heavy)
        bubbleText.fontSize = 12
        bubbleText.foregroundColor = CGColor(srgbRed: 0.25, green: 0.13, blue: 0.05, alpha: 1)
        bubbleText.alignmentMode = .center
        bubble.addSublayer(bubbleBackground)
        bubble.addSublayer(bubbleText)
        bubble.isHidden = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onBoop() }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        (pool + [bubbleBackground]).forEach { $0.contentsScale = scale }
        bubbleText.contentsScale = scale
    }

    func render(_ pose: Doxie.Pose, bubble text: String?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var canvas = LayerCanvas(view: self)
        Doxie.draw(&canvas, pose)
        for layer in pool[canvas.used...] where !layer.isHidden { layer.isHidden = true }
        updateBubble(text, above: CGPoint(x: pose.pos.x, y: pose.pos.y - 48))
        CATransaction.commit()
    }

    fileprivate func shape(_ i: Int) -> CAShapeLayer {
        while pool.count <= i {
            let l = CAShapeLayer()
            l.lineCap = .round
            l.contentsScale = window?.backingScaleFactor ?? 2
            dog.addSublayer(l)
            pool.append(l)
        }
        return pool[i]
    }

    private func updateBubble(_ text: String?, above p: CGPoint) {
        guard let text else { bubble.isHidden = true; bubbleString = nil; return }
        if text != bubbleString {
            bubbleString = text
            let width = (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .heavy)]).width + 16
            let box = CGRect(x: -width / 2, y: -20, width: width, height: 20)
            bubbleBackground.path = CGPath(roundedRect: box, cornerWidth: 10, cornerHeight: 10, transform: nil)
            bubbleText.string = text
            bubbleText.frame = box.offsetBy(dx: 0, dy: 3)
        }
        bubble.position = p
        bubble.isHidden = false
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
