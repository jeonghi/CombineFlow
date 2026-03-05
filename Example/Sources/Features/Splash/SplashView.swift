import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("CombineFlow")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Architecture Example")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
