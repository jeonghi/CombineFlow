import SwiftUI

struct FlowDetailView: View {
    let title: String
    let description: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title2.weight(.bold))

                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Divider()

                Text("이 화면은 Flow가 Step을 받아 UINavigationController로 push한 2depth 예시입니다.")
                    .font(.callout)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(Color(.systemBackground))
    }
}
