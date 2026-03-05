// Example/Sources/Services/AuthenticationService.swift
import Combine
import Foundation

final class AuthenticationService: @unchecked Sendable {
    static let shared = AuthenticationService()
    private init() {}

    enum AuthEvent: Equatable {
        case loggedIn(token: String)
        case loggedOut
        case tokenExpired
    }

    private(set) var token: String?
    let authEvents = PassthroughSubject<AuthEvent, Never>()

    private var expirationTask: Task<Void, Never>?

    func login(token: String) {
        self.token = token
        authEvents.send(.loggedIn(token: token))
    }

    func logout() {
        expirationTask?.cancel()
        expirationTask = nil
        token = nil
        authEvents.send(.loggedOut)
    }

    func expireToken() {
        expirationTask?.cancel()
        expirationTask = nil
        token = nil
        authEvents.send(.tokenExpired)
    }

    func startExpirationTimer(after seconds: TimeInterval) {
        expirationTask?.cancel()
        expirationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.expireToken()
        }
    }
}
