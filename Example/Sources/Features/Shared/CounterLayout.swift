import SwiftUI

struct CounterLayout: View {
    let title: String
    let subtitle: String
    let count: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onReset: () -> Void

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
            .padding(.top, 32)

            Spacer()

            Text("\(count)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: count)

            Spacer()

            HStack(spacing: 24) {
                CircleButton(symbol: "minus", color: .red) { onDecrement() }
                CircleButton(symbol: "arrow.counterclockwise", color: .gray) { onReset() }
                CircleButton(symbol: "plus", color: .green) { onIncrement() }
            }
            .padding(.bottom, 48)
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
                .shadow(color: color.opacity(0.4), radius: 8, y: 4)
        }
    }
}
