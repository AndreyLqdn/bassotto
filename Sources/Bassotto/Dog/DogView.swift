import SwiftUI

/// Placeholder dog until the Blender clips exist (M2): an SF Symbol with a little
/// walking wobble at 30 fps. The timeline only ticks while he walks.
struct DogView: View {
    let dog: DogModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !dog.isWalking)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let step = dog.isWalking ? sin(t * 14) : 0

            Image(systemName: "dog.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color(red: 0.62, green: 0.36, blue: 0.20))
                .frame(width: 96, height: 72)
                // The SF Symbol faces left, so mirror it when walking right.
                .scaleEffect(x: dog.facingRight ? -1 : 1, y: 1)
                .rotationEffect(.degrees(step * 3))
                .offset(y: -abs(step) * 3 - (dog.isHopping ? 22 : 0))
                .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                .contentShape(Rectangle())
                .onTapGesture { dog.hop() }
        }
        .frame(width: 140, height: 120, alignment: .bottom)
    }
}
