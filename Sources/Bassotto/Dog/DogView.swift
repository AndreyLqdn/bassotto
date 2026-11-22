import SwiftUI

/// The stand-in dog: a flat dachshund drawn in code until the Blender clips exist.
/// The timeline only ticks while he walks (30 fps); at rest nothing redraws.
struct DogView: View {
    let dog: DogModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !dog.isWalking)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate * 13
            Canvas { ctx, _ in
                Dachshund.draw(&ctx, pose: .init(phase: phase, walking: dog.isWalking))
            }
            .frame(width: Dachshund.size.width, height: Dachshund.size.height)
            .scaleEffect(x: dog.facingRight ? 1 : -1, y: 1)
            .offset(y: dog.isHopping ? -18 : 0)
            .contentShape(Rectangle())
            .onTapGesture { dog.hop() }
        }
        .frame(width: StageMetrics.size.width, height: StageMetrics.size.height, alignment: .bottom)
    }
}

enum StageMetrics {
    /// Room for the dog plus a hop above him.
    static let size = CGSize(width: 110, height: 70)
}
