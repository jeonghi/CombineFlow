import Foundation

@MainActor
final class MVICounterModel: ObservableObject {
    @Published private(set) var count = 0

    enum Intent {
        case increment
        case decrement
        case reset
    }

    func process(_ intent: Intent) {
        switch intent {
        case .increment:
            count += 1
        case .decrement:
            count -= 1
        case .reset:
            count = 0
        }
    }
}
