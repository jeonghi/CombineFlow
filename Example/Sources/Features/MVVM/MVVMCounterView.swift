import SwiftUI

struct MVVMCounterView: View {
    @StateObject private var viewModel = MVVMCounterViewModel()
    let onShowDetail: () -> Void

    init(onShowDetail: @escaping () -> Void = {}) {
        self.onShowDetail = onShowDetail
    }

    var body: some View {
        CounterLayout(
            title: "MVVM",
            subtitle: "ViewModel + @Published",
            count: viewModel.count,
            onIncrement: viewModel.increment,
            onDecrement: viewModel.decrement,
            onReset: viewModel.reset,
            onShowDetail: onShowDetail
        )
    }
}
