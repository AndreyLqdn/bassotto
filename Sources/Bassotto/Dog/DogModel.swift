import Observation
import SwiftUI

/// What the dog is doing right now. Views read it; the stage and brain write it.
@MainActor
@Observable
final class DogModel {
    var facingRight = true
    var isWalking = false
    var isVisible = true
    private(set) var isHopping = false

    func hop() {
        guard !isHopping else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { isHopping = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isHopping = false }
        }
    }
}
