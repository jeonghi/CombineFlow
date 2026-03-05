import SwiftUI

struct MVICounterView: View {
    @StateObject private var model = MVICounterModel()
    let onShowDetail: () -> Void

    init(onShowDetail: @escaping () -> Void = {}) {
        self.onShowDetail = onShowDetail
    }

    var body: some View {
        CounterLayout(
            title: "MVI",
            subtitle: "Intent -> Model -> View",
            count: model.count,
            onIncrement: { model.process(.increment) },
            onDecrement: { model.process(.decrement) },
            onReset: { model.process(.reset) },
            onShowDetail: onShowDetail
        )
    }
}
