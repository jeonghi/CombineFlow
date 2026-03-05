// Publisher+Pausable.swift
// CombineFlow

import Combine
import Foundation

private final class PauserSubscriptionBag {
    var cancellables = Set<AnyCancellable>()

    func cancelAll() {
        self.cancellables.forEach { $0.cancel() }
        self.cancellables.removeAll()
    }
}

public extension Publisher where Failure == Never {
    /// pauser publisher의 최신 값이 true일 때만 요소를 전달합니다.
    func pausable<P: Publisher>(
        withPauser pauser: P
    ) -> AnyPublisher<Output, Never> where P.Output == Bool, P.Failure == Never {
        let source = self
        return Deferred {
            let bag = PauserSubscriptionBag()
            let lock = NSRecursiveLock()
            let latestResumeState = CurrentValueSubject<Bool, Never>(false)

            pauser.sink { latestResumeState.send($0) }.store(in: &bag.cancellables)

            return source
                .filter { _ in
                    lock.lock(); defer { lock.unlock() }
                    return latestResumeState.value
                }
                .handleEvents(
                    receiveCompletion: { _ in bag.cancelAll() },
                    receiveCancel: { bag.cancelAll() }
                )
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    /// count개 event 이후부터 pauser를 적용합니다.
    func pausable<P: Publisher>(
        afterCount count: Int,
        withPauser pauser: P
    ) -> AnyPublisher<Output, Never> where P.Output == Bool, P.Failure == Never {
        let source = self
        return Deferred {
            let bag = PauserSubscriptionBag()
            let lock = NSRecursiveLock()
            let latestResumeState = CurrentValueSubject<Bool, Never>(false)
            var emittedCount = 0

            pauser.sink { latestResumeState.send($0) }.store(in: &bag.cancellables)

            return source
                .filter { _ in
                    lock.lock(); defer { lock.unlock() }
                    let shouldEmit = (emittedCount < count) || latestResumeState.value
                    if shouldEmit { emittedCount += 1 }
                    return shouldEmit
                }
                .handleEvents(
                    receiveCompletion: { _ in bag.cancelAll() },
                    receiveCancel: { bag.cancelAll() }
                )
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}
