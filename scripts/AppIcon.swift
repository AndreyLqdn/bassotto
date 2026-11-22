// Renders the app icon (the dog's head on a cream rounded square) into an .iconset.
// Run via `make icon`, which compiles this together with Sources/Bassotto/Dog/DogArt.swift.
import AppKit
import SwiftUI

@MainActor func renderIcon(side: CGFloat) -> Data? {
    let corner = side * 0.225
    let inset = side * 0.1   // macOS icon grid: artwork sits inside a ~10% margin
    let icon = ZStack {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color(red: 0.96, green: 0.91, blue: 0.83))
            .shadow(color: .black.opacity(0.18), radius: side * 0.012, y: side * 0.01)
        Canvas { ctx, size in
            DogArt.headIcon(&ctx, in: CGRect(origin: .zero, size: size).insetBy(dx: side * 0.16, dy: side * 0.16))
        }
    }
    .padding(inset)
    .frame(width: side, height: side)

    let renderer = ImageRenderer(content: icon)
    renderer.scale = 1
    guard let image = renderer.cgImage else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

@main struct AppIcon {
    static func main() {
        MainActor.assumeIsolated {
            let dir = URL(fileURLWithPath: CommandLine.arguments[1])
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for base in [16, 32, 128, 256, 512] {
                for (scale, suffix) in [(1, ""), (2, "@2x")] {
                    let name = "icon_\(base)x\(base)\(suffix).png"
                    if let png = renderIcon(side: CGFloat(base * scale)) {
                        try? png.write(to: dir.appendingPathComponent(name))
                    }
                }
            }
        }
    }
}
