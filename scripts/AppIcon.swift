// Renders the app icon (the dog resting on a little Dock, on a cream tile) into an .iconset.
// Run via `make icon`, which compiles this together with Sources/Bassotto/Dog/Doxie.swift.
import AppKit

func renderIcon(side: Int) -> Data? {
    let s = CGFloat(side)
    guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.translateBy(x: 0, y: s); ctx.scaleBy(x: 1, y: -1)                       // y-down

    let tile = CGRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)  // macOS icon grid margin
    let tilePath = CGPath(roundedRect: tile, cornerWidth: s * 0.18, cornerHeight: s * 0.18, transform: nil)
    ctx.addPath(tilePath)
    ctx.setFillColor(CGColor(srgbRed: 0.97, green: 0.94, blue: 0.88, alpha: 1))
    ctx.fillPath()

    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    // A little Dock for him to lie on.
    let dockY = s * 0.66
    ctx.setFillColor(CGColor(srgbRed: 0.80, green: 0.81, blue: 0.84, alpha: 1))
    ctx.fill(CGRect(x: tile.minX, y: dockY, width: tile.width, height: tile.maxY - dockY))
    Doxie.draw(ctx, .rest(blink: false, breath: 0), at: CGPoint(x: s * 0.42, y: dockY), scale: s / 190)
    ctx.restoreGState()

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
