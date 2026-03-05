import ComposableArchitecture
import SwiftUI

struct TCACounterView: View {
    @Bindable var store: StoreOf<TCACounterFeature>

    var body: some View {
        CounterLayout(
            title: "TCA",
            subtitle: "Reducer + Store",
            count: store.count,
            onIncrement: { store.send(.increment) },
            onDecrement: { store.send(.decrement) },
            onReset: { store.send(.reset) }
        )
    }
}
