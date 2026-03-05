import SwiftUI

struct MVVMCounterView: View {
    @StateObject private var viewModel = MVVMCounterViewModel()

    var body: some View {
        CounterLayout(
            title: "MVVM",
            subtitle: "ViewModel + @Published",
            count: viewModel.count,
            onIncrement: viewModel.increment,
            onDecrement: viewModel.decrement,
            onReset: viewModel.reset
        )
    }
}
