import Combine
import UIKit
import XCTest

@testable import CombineFlow

private enum TestStep: Step, Equatable {
    case initial
    case emittedFromReady
    case startContribution
    case contributedStep
    case gatingStep
    case childForwarded
}

private enum ChildStep: Step {
    case start
}

private final class EagerReadyStepper: Stepper {
    let steps = PublishRelay<Step>()
    let initialStep: Step
    private let stepsToEmitWhenReady: [Step]

    init(initialStep: Step, stepsToEmitWhenReady: [Step]) {
        self.initialStep = initialStep
        self.stepsToEmitWhenReady = stepsToEmitWhenReady
    }

    func readyToEmitSteps() {
        self.stepsToEmitWhenReady.forEach { self.steps.accept($0) }
    }
}

private final class ManualStepper: Stepper {
    let steps = PublishRelay<Step>()
    let initialStep: Step

    init(initialStep: Step = NoneStep()) {
        self.initialStep = initialStep
    }
}

private final class ImmediateDismissedPresentable: Presentable {
    var visible: AnyPublisher<Bool, Never> {
        Just(true).eraseToAnyPublisher()
    }

    var dismissed: AnyPublisher<Void, Never> {
        Just(()).eraseToAnyPublisher()
    }
}

private final class SubjectPresentable: Presentable {
    let visibleSubject: CurrentValueSubject<Bool, Never>
    let dismissedSubject = PassthroughSubject<Void, Never>()

    init(isVisible: Bool) {
        self.visibleSubject = CurrentValueSubject(isVisible)
    }

    var visible: AnyPublisher<Bool, Never> {
        self.visibleSubject.eraseToAnyPublisher()
    }

    var dismissed: AnyPublisher<Void, Never> {
        self.dismissedSubject.eraseToAnyPublisher()
    }
}

@MainActor
private final class RecordingFlow: Flow {
    let rootViewController = UIViewController()
    private(set) var handledSteps = [TestStep]()
    private let contributionProvider: (TestStep) -> FlowContributors

    var root: Presentable { self.rootViewController }

    init(contributionProvider: @escaping (TestStep) -> FlowContributors = { _ in .none }) {
        self.contributionProvider = contributionProvider
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? TestStep else { return .none }
        self.handledSteps.append(step)
        return self.contributionProvider(step)
    }
}

@MainActor
private final class ChildForwardingFlow: Flow {
    let rootViewController = UIViewController()
    var root: Presentable { self.rootViewController }

    func navigate(to step: Step) -> FlowContributors {
        guard step is ChildStep else { return .none }
        return .one(flowContributor: .forwardToParentFlow(withStep: TestStep.childForwarded))
    }
}

@MainActor
final class FlowCoordinatorMigrationTests: XCTestCase {
    func test_listen_capturesSynchronousStepsFromReadyToEmitSteps() {
        let coordinator = FlowCoordinator()
        let flow = RecordingFlow()
        let stepper = EagerReadyStepper(
            initialStep: TestStep.initial,
            stepsToEmitWhenReady: [TestStep.emittedFromReady]
        )

        coordinator.coordinate(flow: flow, with: stepper)

        XCTAssertEqual(flow.handledSteps.count, 2)
        XCTAssertTrue(flow.handledSteps.contains(TestStep.initial))
        XCTAssertTrue(flow.handledSteps.contains(TestStep.emittedFromReady))
    }

    func test_flowsUseReady_executesForLateSubscription() {
        let coordinator = FlowCoordinator()
        let flow = RecordingFlow()
        let readyExpectation = self.expectation(description: "Flows.use ready block called")

        coordinator.coordinate(
            flow: flow,
            with: OneStepper(withSingleStep: TestStep.initial)
        )

        Flows.use([flow], when: .ready) { (roots: [UIViewController]) in
            XCTAssertEqual(roots.count, 1)
            readyExpectation.fulfill()
        }

        self.wait(for: [readyExpectation], timeout: 0.5)
    }

    func test_listen_blocksStepsWhenPresentableIsImmediatelyDismissed() {
        let dismissedPresentable = ImmediateDismissedPresentable()
        let childStepper = EagerReadyStepper(
            initialStep: TestStep.contributedStep,
            stepsToEmitWhenReady: [TestStep.contributedStep]
        )
        let flow = RecordingFlow { step in
            guard step == .startContribution else { return .none }
            return .one(flowContributor: .contribute(
                withNextPresentable: dismissedPresentable,
                withNextStepper: childStepper,
                allowStepWhenNotPresented: true,
                allowStepWhenDismissed: false
            ))
        }

        let coordinator = FlowCoordinator()
        coordinator.coordinate(
            flow: flow,
            with: OneStepper(withSingleStep: TestStep.startContribution)
        )

        XCTAssertEqual(flow.handledSteps, [.startContribution])
    }

    func test_listen_respectsVisibilityGateWhenAllowStepWhenNotPresentedIsFalse() {
        let visibilityPresentable = SubjectPresentable(isVisible: false)
        let childStepper = ManualStepper()
        let flow = RecordingFlow { step in
            guard step == .startContribution else { return .none }
            return .one(flowContributor: .contribute(
                withNextPresentable: visibilityPresentable,
                withNextStepper: childStepper,
                allowStepWhenNotPresented: false,
                allowStepWhenDismissed: false
            ))
        }

        let coordinator = FlowCoordinator()
        coordinator.coordinate(
            flow: flow,
            with: OneStepper(withSingleStep: TestStep.startContribution)
        )

        childStepper.steps.accept(TestStep.gatingStep)
        visibilityPresentable.visibleSubject.send(true)
        childStepper.steps.accept(TestStep.gatingStep)

        let gatedSteps = flow.handledSteps.filter { $0 == .gatingStep }
        XCTAssertEqual(gatedSteps.count, 1)
    }

    func test_forwardToParentFlow_fromChildFlow_reachesParentFlow() {
        let childFlow = ChildForwardingFlow()
        let parentFlow = RecordingFlow { step in
            guard step == .initial else { return .none }
            return .one(flowContributor: .contribute(
                withNextPresentable: childFlow,
                withNextStepper: OneStepper(withSingleStep: ChildStep.start)
            ))
        }

        let coordinator = FlowCoordinator()
        coordinator.coordinate(
            flow: parentFlow,
            with: OneStepper(withSingleStep: TestStep.initial)
        )

        XCTAssertTrue(parentFlow.handledSteps.contains(TestStep.childForwarded))
    }

    func test_flowsUseCreated_ignoresRootTypeMismatchWithoutExecutingBlock() {
        let flow = RecordingFlow()
        let didRunBlock = expectation(description: "type-mismatch block should not run")
        didRunBlock.isInverted = true

        Flows.use([flow], when: .created) { (_: [UINavigationController]) in
            didRunBlock.fulfill()
        }

        self.wait(for: [didRunBlock], timeout: 0.1)
    }
}
