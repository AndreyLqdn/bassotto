import Observation

/// What the dog is doing right now. The stage writes it; the view and menu read it.
@MainActor
@Observable
final class DogModel {
    var facingRight = true { didSet { onChange?() } }
    var isWalking = false { didSet { onChange?() } }
    var isAsleep = false { didSet { onChange?() } }
    var isVisible = true

    @ObservationIgnored var onChange: (() -> Void)?

    var pose: Kawaii.Pose {
        if isWalking { return .walk }
        return isAsleep ? .sleep : .rest
    }
}
