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

    private var cache: [Kawaii.Pose: Loop] = [:]
    private let scale: CGFloat
    private let pixelScale: CGFloat

    init(scale: CGFloat, pixelScale: CGFloat) {
        self.scale = scale
        self.pixelScale = pixelScale
    }

    /// Frame count and length of each loop.
    private static func spec(_ pose: Kawaii.Pose) -> (frames: Int, duration: Double) {
        switch pose {
        case .rest: (48, 4.0)     // 12 fps: one slow breath, six wags
        case .sleep: (48, 4.0)    // 12 fps: one breath, bubble, drifting Zzz
        case .walk: (12, 0.55)    // ~22 fps: one stride
        }
    }

    func loop(_ pose: Kawaii.Pose) -> Loop {
        if let cached = cache[pose] { return cached }
        let (count, duration) = Self.spec(pose)
        let scale = self.scale
        let size = CGSize(width: Kawaii.canvas.width * scale, height: Kawaii.canvas.height * scale)
        let frames: [CGImage] = (0..<count).compactMap { i in
            let motion = Kawaii.Motion(u: Double(i) / Double(count), walking: pose == .walk)
            let renderer = ImageRenderer(content:
                Canvas { ctx, _ in Kawaii.draw(&ctx, pose: pose, motion: motion, scale: scale) }
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
