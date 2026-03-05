import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("⚡")
                    .font(.system(size: 64))
                Text("CombineFlow")
                    .font(.largeTitle.bold())
                Text("Architecture Examples")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
