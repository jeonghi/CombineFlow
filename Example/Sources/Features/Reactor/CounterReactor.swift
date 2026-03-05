import Foundation

@MainActor
final class CounterReactor: ObservableObject {
    enum Action {
        case increment
        case decrement
        case reset
    }

    enum Mutation {
        case setCount(Int)
    }

    struct State: Equatable {
        var count = 0
    }

    @Published private(set) var state = State()

    func action(_ action: Action) {
        mutate(action: action).forEach { mutation in
            state = reduce(state: state, mutation: mutation)
        }
    }

    private func mutate(action: Action) -> [Mutation] {
        switch action {
        case .increment:
            return [.setCount(state.count + 1)]
        case .decrement:
            return [.setCount(state.count - 1)]
        case .reset:
            return [.setCount(0)]
        }
    }

    private func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case .setCount(let value):
            newState.count = value
        }
        return newState
    }
}
