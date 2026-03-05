import SwiftUI

struct MVICounterView: View {
    @StateObject private var model = MVICounterModel()

    var body: some View {
        CounterLayout(
            title: "MVI",
            subtitle: "Intent → Model → View",
            count: model.count,
            onIncrement: { model.process(.increment) },
            onDecrement: { model.process(.decrement) },
            onReset:     { model.process(.reset) }
        )
    }
}
