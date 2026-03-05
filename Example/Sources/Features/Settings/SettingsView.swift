import SwiftUI

struct SettingsView: View {
    let onShowDetail: () -> Void

    @State private var tokenDisplay = "None"
    @State private var timerEnabled = false

    init(onShowDetail: @escaping () -> Void = {}) {
        self.onShowDetail = onShowDetail
    }

    var body: some View {
        List {
            Section("Account") {
                HStack {
                    Text("Token")
                    Spacer()
                    Text(tokenDisplay)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Button("Logout", role: .destructive) {
                    AuthenticationService.shared.logout()
                    refreshTokenDisplay()
                    timerEnabled = false
                }
            }

            Section("Navigation") {
                Button("Open Detail") {
                    onShowDetail()
                }
            }

            Section("Developer") {
                Button("Expire token") {
                    AuthenticationService.shared.expireToken()
                    refreshTokenDisplay()
                    timerEnabled = false
                }
                .foregroundStyle(.orange)

                Toggle("Auto expire in 30s", isOn: $timerEnabled)
                    .onChange(of: timerEnabled) { _, isEnabled in
                        if isEnabled {
                            AuthenticationService.shared.startExpirationTimer(after: 30)
                        } else {
                            AuthenticationService.shared.cancelExpirationTimer()
                        }
                    }
            }
        }
        .navigationTitle("Settings")
        .onAppear { refreshTokenDisplay() }
    }

    private func refreshTokenDisplay() {
        if let token = AuthenticationService.shared.token {
            tokenDisplay = String(token.prefix(8)) + "..."
        } else {
            tokenDisplay = "None"
        }
    }
}
