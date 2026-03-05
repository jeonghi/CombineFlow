import SwiftUI

struct ReactorCounterView: View {
    @StateObject private var reactor = CounterReactor()

    var body: some View {
        CounterLayout(
            title: "Reactor",
            subtitle: "Action → Mutation → State",
            count: reactor.state.count,
            onIncrement: { reactor.action(.increment) },
            onDecrement: { reactor.action(.decrement) },
            onReset:     { reactor.action(.reset) }
        )
    }
}
