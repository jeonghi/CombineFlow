// Stepper.swift
// CombineFlow

import Combine

/// Combine의 `PassthroughSubject`를 기반으로 하는 가벼운 relay.
public final class PublishRelay<Element>: Publisher {
    public typealias Output = Element
    public typealias Failure = Never

    private let subject = PassthroughSubject<Element, Never>()

    public init() {}

    public func accept(_ element: Element) {
        self.subject.send(element)
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Element == S.Input {
        self.subject.receive(subscriber: subscriber)
    }

    public func eraseToAnyPublisher() -> AnyPublisher<Element, Never> {
        self.subject.eraseToAnyPublisher()
    }
}

/// Stepper는 특정 navigation 상태에 해당하는 Step을 방출합니다.
public protocol Stepper {
    var steps: PublishRelay<Step> { get }
    var initialStep: Step { get }
    func readyToEmitSteps()
}

public extension Stepper {
    var initialStep: Step { NoneStep() }
    func readyToEmitSteps() {}
}

/// 단일 Step만 방출하는 Stepper.
public class OneStepper: Stepper {
    public let steps = PublishRelay<Step>()
    private let singleStep: Step

    public init(withSingleStep singleStep: Step) {
        self.singleStep = singleStep
    }

    public var initialStep: Step { self.singleStep }
}

/// 기본 초기 Step으로 CombineFlowStep.home을 방출하는 Stepper.
public class DefaultStepper: OneStepper {
    public init() {
        super.init(withSingleStep: CombineFlowStep.home)
    }
}

/// 여러 Stepper를 결합한 Stepper.
public class CompositeStepper: Stepper {
    private var cancellables = Set<AnyCancellable>()
    private let innerSteppers: [Stepper]
    public let steps = PublishRelay<Step>()

    public init(steppers: [Stepper]) {
        self.innerSteppers = steppers
    }

    public func readyToEmitSteps() {
        self.cancellables.removeAll()
        self.innerSteppers.forEach { self.steps.accept($0.initialStep) }

        Publishers.MergeMany(self.innerSteppers.map { $0.steps.eraseToAnyPublisher() })
            .sink { [weak self] step in self?.steps.accept(step) }
            .store(in: &self.cancellables)

        self.innerSteppers.forEach { $0.readyToEmitSteps() }
    }
}

public final class NoneStepper: OneStepper {
    public convenience init() { self.init(withSingleStep: NoneStep()) }
}
