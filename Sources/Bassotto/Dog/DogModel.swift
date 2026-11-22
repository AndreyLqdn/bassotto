import Observation

/// What the dog is doing right now. The stage writes it; the view and menu read it.
@MainActor
@Observable
final class DogModel {
    enum Gait { case still, trot, run }

    var facingRight = true { didSet { onChange?() } }
    var gait: Gait = .still { didSet { onChange?() } }
    var isAsleep = false { didSet { onChange?() } }
    var isVisible = true

    @ObservationIgnored var onChange: (() -> Void)?

    var isMoving: Bool { gait != .still }

    var pose: DogArt.Pose {
        switch gait {
        case .run: .run
        case .trot: .trot
        case .still: isAsleep ? .sleep : .stand
        }
    }
}
