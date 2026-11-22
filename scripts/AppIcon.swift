// Renders the app icon (the dog on a cream rounded square) into an .iconset.
// Run via `make icon`, which compiles this together with Sources/Bassotto/Dog/Doxie.swift.
import AppKit

func renderIcon(side: Int) -> Data? {
    let s = CGFloat(side)
    guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    // Flip to y-down so Doxie's coordinates apply.
    ctx.translateBy(x: 0, y: s); ctx.scaleBy(x: 1, y: -1)

    let tile = CGRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)   // macOS icon grid margin
    ctx.addPath(CGPath(roundedRect: tile, cornerWidth: s * 0.18, cornerHeight: s * 0.18, transform: nil))
    ctx.setFillColor(CGColor(srgbRed: 0.97, green: 0.93, blue: 0.86, alpha: 1))
    ctx.fillPath()

    // The dog, three-quarter view, centred in the tile.
    let scale = s / 130
    ctx.translateBy(x: s * 0.5, y: s * 0.57)
    ctx.scaleBy(x: scale, y: scale)
    let heading: CGFloat = 0.35
    let pose = Doxie.Pose(pos: .zero, heading: heading,
                          feet: (0..<4).map { Doxie.restingFoot($0, pos: .zero, heading: heading) },
                          wag: 0.5)
    Doxie.draw(ctx, pose)

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
