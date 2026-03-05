// Example/Sources/Services/AuthenticationService.swift
import Combine
import Foundation

@MainActor
final class AuthenticationService {
    static let shared = AuthenticationService()
    private init() {}

    enum AuthEvent: Equatable {
        case loggedIn(token: String)
        case loggedOut
        case tokenExpired
    }

    private(set) var token: String?
    private let _authEvents = PassthroughSubject<AuthEvent, Never>()
    var authEvents: AnyPublisher<AuthEvent, Never> { _authEvents.eraseToAnyPublisher() }

    private var expirationTask: Task<Void, Never>?

    func login(token: String) {
        expirationTask?.cancel()
        expirationTask = nil
        self.token = token
        _authEvents.send(.loggedIn(token: token))
    }

    func logout() {
        expirationTask?.cancel()
        expirationTask = nil
        token = nil
        _authEvents.send(.loggedOut)
    }

    func expireToken() {
        expirationTask?.cancel()
        expirationTask = nil
        token = nil
        _authEvents.send(.tokenExpired)
    }

    func cancelExpirationTimer() {
        expirationTask?.cancel()
        expirationTask = nil
    }

    func startExpirationTimer(after seconds: TimeInterval) {
        expirationTask?.cancel()
        expirationTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(min(seconds, 3600) * 1_000_000_000))
                await self?.expireToken()
            } catch {
                // Task was cancelled; do nothing.
            }
        }
    }
}
