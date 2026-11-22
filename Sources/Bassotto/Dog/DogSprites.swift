import AppKit
import SwiftUI

/// Pre-renders each pose's animation loop into frames once, so playback can be handed
/// to Core Animation and cost the app ~0% CPU (the window server flips the frames).
@MainActor
final class DogSprites {
    struct Loop {
        let frames: [CGImage]
        let duration: CFTimeInterval
    }

    private var cache: [DogArt.Pose: Loop] = [:]
    private let scale: CGFloat
    private let pixelScale: CGFloat

    init(scale: CGFloat, pixelScale: CGFloat) {
        self.scale = scale
        self.pixelScale = pixelScale
    }

    /// Frame count and length of each loop.
    private static func spec(_ pose: DogArt.Pose) -> (frames: Int, duration: Double) {
        switch pose {
        case .stand: (48, 4.0)    // 12 fps: one slow breath, three wags
        case .sleep: (48, 4.0)    // 12 fps: one breath, drifting Zzz
        case .trot: (10, 0.42)    // ~24 fps: one stride
        case .run: (8, 0.2)       // 40 fps: frantic little legs
        }
    }

    func loop(_ pose: DogArt.Pose) -> Loop {
        if let cached = cache[pose] { return cached }
        let (count, duration) = Self.spec(pose)
        let scale = self.scale
        let size = CGSize(width: DogArt.canvas.width * scale, height: DogArt.canvas.height * scale)
        let frames: [CGImage] = (0..<count).compactMap { i in
            let u = Double(i) / Double(count)
            let renderer = ImageRenderer(content:
                Canvas { ctx, _ in DogArt.draw(&ctx, pose: pose, u: u, scale: scale) }
                    .frame(width: size.width, height: size.height)
            )
            renderer.scale = pixelScale
            return renderer.cgImage
        }
        let loop = Loop(frames: frames, duration: duration)
        cache[pose] = loop
        return loop
    }
}
