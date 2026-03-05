import ComposableArchitecture
import SwiftUI

struct TCACounterView: View {
    @Bindable var store: StoreOf<TCACounterFeature>
    let onShowDetail: () -> Void

    init(store: StoreOf<TCACounterFeature>, onShowDetail: @escaping () -> Void = {}) {
        self.store = store
        self.onShowDetail = onShowDetail
    }

    var body: some View {
        CounterLayout(
            title: "TCA",
            subtitle: "Reducer + Store",
            count: store.count,
            onIncrement: { store.send(.increment) },
            onDecrement: { store.send(.decrement) },
            onReset: { store.send(.reset) },
            onShowDetail: onShowDetail
        )
    }
}
