import SwiftUI

struct DetailView: View {
    let count: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Detail")
                .font(.largeTitle.bold())
            Text("Final count: \(count)")
                .font(.title2)
                .foregroundStyle(.secondary)
            Button("Back to Counter") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
