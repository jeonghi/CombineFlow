import SwiftUI

struct CounterLayout: View {
    let title: String
    let subtitle: String
    let count: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onReset: () -> Void
    let onShowDetail: (() -> Void)?

    init(
        title: String,
        subtitle: String,
        count: Int,
        onIncrement: @escaping () -> Void,
        onDecrement: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onShowDetail: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.count = count
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
        self.onReset = onReset
        self.onShowDetail = onShowDetail
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)

            Spacer()

            Text("\(count)")
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.25), value: count)

            if let onShowDetail {
                Button {
                    onShowDetail()
                } label: {
                    Label("Open Detail", systemImage: "arrow.right.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .padding(.top, 18)
            }

            Spacer()

            HStack(spacing: 22) {
                CircleButton(symbol: "minus", color: .red, action: onDecrement)
                CircleButton(symbol: "arrow.counterclockwise", color: .gray, action: onReset)
                CircleButton(symbol: "plus", color: .green, action: onIncrement)
            }
            .padding(.bottom, 42)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CircleButton: View {
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(color)
                .clipShape(Circle())
                .shadow(color: color.opacity(0.35), radius: 8, y: 4)
        }
    }
}
