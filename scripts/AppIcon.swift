// Renders the app icon into an .iconset: the dog, big, in three-quarter view on a soft
// light-grey tile (the same recipe as Desktop Goose's icon, with our dog).
// Run via `make icon`, which compiles this together with Sources/Bassotto/Dog/Doxie.swift.
import AppKit

func renderIcon(side: Int) -> Data? {
    let s = CGFloat(side)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.translateBy(x: 0, y: s); ctx.scaleBy(x: 1, y: -1)                       // y-down

    // Tile: rounded square, light grey top-to-bottom gradient, hairline border.
    let tile = CGRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: s * 0.18, cornerHeight: s * 0.18, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: s * 0.008), blur: s * 0.02, color: CGColor(gray: 0, alpha: 0.25))
    ctx.addPath(tilePath); ctx.setFillColor(CGColor(gray: 0.88, alpha: 1)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [CGColor(gray: 0.93, alpha: 1), CGColor(gray: 0.80, alpha: 1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: tile.minY), end: CGPoint(x: 0, y: tile.maxY), options: [])
    ctx.restoreGState()
    ctx.addPath(tilePath); ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.7)); ctx.setLineWidth(s * 0.006); ctx.strokePath()

    // The dog: big, standing, heading a little up-right, mid-trot.
    var dog = Doxie.State(pos: CGPoint(x: s * 0.47, y: s * 0.64), direction: -18)
    dog.wag = 0.35
    let f = Doxie.unit(-18)
    for i in 0..<4 {
        let d: CGFloat = (i == 0 || i == 3) ? 3 : -3
        dog.feet[i].x += f.x * d; dog.feet[i].y += f.y * d
    }
    Doxie.draw(ctx, dog, scale: s / 105)

    guard let image = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

@main struct AppIcon {
    static func main() {
        let dir = URL(fileURLWithPath: CommandLine.arguments[1])
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            for (scale, suffix) in [(1, ""), (2, "@2x")] {
                if let png = renderIcon(side: base * scale) {
                    try? png.write(to: dir.appendingPathComponent("icon_\(base)x\(base)\(suffix).png"))
                }
            }
        }
    }
}
