import SwiftUI

struct ReactorCounterView: View {
    @StateObject private var reactor = CounterReactor()
    let onShowDetail: () -> Void

    init(onShowDetail: @escaping () -> Void = {}) {
        self.onShowDetail = onShowDetail
    }

    var body: some View {
        CounterLayout(
            title: "Reactor",
            subtitle: "Action -> Mutation -> State",
            count: reactor.state.count,
            onIncrement: { reactor.action(.increment) },
            onDecrement: { reactor.action(.decrement) },
            onReset: { reactor.action(.reset) },
            onShowDetail: onShowDetail
        )
    }
}
