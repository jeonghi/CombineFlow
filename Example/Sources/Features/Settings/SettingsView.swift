import SwiftUI

struct SettingsView: View {
    @State private var tokenDisplay: String = ""
    @State private var timerActive = false

    var body: some View {
        NavigationStack {
            List {
                Section("계정") {
                    tokenRow
                    logoutButton
                }
                Section("개발자 도구") {
                    expireButton
                    timerToggle
                }
            }
            .navigationTitle("Settings")
            .onAppear { refreshToken() }
        }
    }

    private var tokenRow: some View {
        HStack {
            Text("토큰")
            Spacer()
            Text(tokenDisplay)
                .foregroundStyle(.secondary)
                .font(.caption.monospaced())
        }
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            AuthenticationService.shared.logout()
        } label: {
            Text("로그아웃")
        }
    }

    private var expireButton: some View {
        Button("토큰 만료 시뮬레이션") {
            AuthenticationService.shared.expireToken()
        }
        .foregroundStyle(.orange)
    }

    private var timerToggle: some View {
        Toggle("30초 후 자동 만료", isOn: $timerActive)
            .onChange(of: timerActive) { _, active in
                if active {
                    AuthenticationService.shared.startExpirationTimer(after: 30)
                }
            }
    }

    private func refreshToken() {
        if let t = AuthenticationService.shared.token {
            tokenDisplay = String(t.prefix(8)) + "..."
        } else {
            tokenDisplay = "없음"
        }
    }
}
