// FlowCoordinator.swift
// CombineFlow

#if canImport(UIKit)
import Combine
import Foundation

public final class FlowCoordinator: NSObject {
    private var cancellables = Set<AnyCancellable>()
    private var childFlowCoordinators = [String: FlowCoordinator]()
    private weak var parentFlowCoordinator: FlowCoordinator? {
        didSet {
            guard let parent = self.parentFlowCoordinator else { return }
            self.willNavigateRelay
                .sink { [weak parent] in parent?.willNavigateRelay.accept($0) }
                .store(in: &self.cancellables)
            self.didNavigateRelay
                .sink { [weak parent] in parent?.didNavigateRelay.accept($0) }
                .store(in: &self.cancellables)
        }
    }

    private let stepsRelay = PublishRelay<Step>()
    private let willNavigateRelay = PublishRelay<(Flow, Step)>()
    private let didNavigateRelay = PublishRelay<(Flow, Step)>()

    internal let identifier = UUID().uuidString

    public var willNavigate: AnyPublisher<(Flow, Step), Never> {
        self.willNavigateRelay.eraseToAnyPublisher()
    }

    public var didNavigate: AnyPublisher<(Flow, Step), Never> {
        self.didNavigateRelay.eraseToAnyPublisher()
    }

    public func coordinate(
        flow: Flow,
        with stepper: Stepper = DefaultStepper(),
        allowStepWhenDismissed: Bool = false
    ) {
        self.stepsRelay
            .receive(on: DispatchQueue.main)
            .sink { [weak self] step in self?.adaptAndNavigate(step: step, in: flow) }
            .store(in: &self.cancellables)

        if !allowStepWhenDismissed {
            flow.dismissed
                .prefix(1)
                .sink { [weak self] _ in self?.cleanupRelations() }
                .store(in: &self.cancellables)
        }

        self.listen(
            to: stepper,
            from: flow,
            allowStepWhenNotPresented: true,
            allowStepWhenDismissed: allowStepWhenDismissed
        )
    }

    public func navigate(to step: Step) {
        self.stepsRelay.accept(step)
        self.childFlowCoordinators.values.forEach { $0.navigate(to: step) }
    }

    private func adaptAndNavigate(step: Step, in flow: Flow) {
        flow.adapt(step: step)
            .prefix(1)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] adaptedStep in
                guard let self else { return }
                self.willNavigateRelay.accept((flow, adaptedStep))
                let flowContributors = flow.navigate(to: adaptedStep)
                self.didNavigateRelay.accept((flow, adaptedStep))
                self.handle(flowContributors: flowContributors, in: flow)
            }
            .store(in: &self.cancellables)
    }

    private func handle(flowContributors: FlowContributors, in flow: Flow) {
        self.performSideEffects(with: flowContributors)
        let presentableAndSteppers = self.nextPresentablesAndSteppers(from: flowContributors)
        self.setReadiness(for: flow, basedOn: presentableAndSteppers.map { $0.presentable })
        presentableAndSteppers.forEach { next in
            if let childFlow = next.presentable as? Flow {
                let childCoordinator = FlowCoordinator()
                childCoordinator.parentFlowCoordinator = self
                self.childFlowCoordinators[childCoordinator.identifier] = childCoordinator
                childCoordinator.coordinate(
                    flow: childFlow,
                    with: next.stepper,
                    allowStepWhenDismissed: next.allowStepWhenDismissed
                )
                return
            }
            self.listen(
                to: next.stepper,
                from: next.presentable,
                allowStepWhenNotPresented: next.allowStepWhenNotPresented,
                allowStepWhenDismissed: next.allowStepWhenDismissed
            )
        }
    }

    private func cleanupRelations() {
        self.childFlowCoordinators.removeAll()
        self.parentFlowCoordinator?.childFlowCoordinators.removeValue(forKey: self.identifier)
    }

    private func performSideEffects(with flowContributors: FlowContributors) {
        switch flowContributors {
        case let .one(fc): self.performSideEffects(with: fc)
        case .end(let step):
            self.parentFlowCoordinator?.stepsRelay.accept(step)
            self.cleanupRelations()
        case let .multiple(fcs): fcs.forEach { self.performSideEffects(with: $0) }
        case .none: break
        }
    }

    private func performSideEffects(with flowContributor: FlowContributor) {
        switch flowContributor {
        case let .forwardToCurrentFlow(step): self.stepsRelay.accept(step)
        case let .forwardToParentFlow(step): self.parentFlowCoordinator?.stepsRelay.accept(step)
        case .contribute: break
        }
    }

    private func nextPresentablesAndSteppers(from flowContributors: FlowContributors) -> [PresentableAndStepper] {
        switch flowContributors {
        case .none, .one(.forwardToCurrentFlow), .one(.forwardToParentFlow), .end:
            return []
        case let .one(.contribute(p, s, allowNotPresented, allowDismissed)):
            return [PresentableAndStepper(
                presentable: p, stepper: s,
                allowStepWhenNotPresented: allowNotPresented,
                allowStepWhenDismissed: allowDismissed
            )]
        case .multiple(let fcs):
            return fcs.compactMap { fc -> PresentableAndStepper? in
                guard case let .contribute(p, s, allowNotPresented, allowDismissed) = fc else { return nil }
                return PresentableAndStepper(
                    presentable: p, stepper: s,
                    allowStepWhenNotPresented: allowNotPresented,
                    allowStepWhenDismissed: allowDismissed
                )
            }
        }
    }

    private func listen(
        to stepper: Stepper,
        from presentable: Presentable,
        allowStepWhenNotPresented: Bool,
        allowStepWhenDismissed: Bool
    ) {
        let context = StepStreamContext(initialVisibility: allowStepWhenNotPresented)

        if !allowStepWhenNotPresented {
            presentable.visible
                .sink { context.isVisible = $0 }
                .store(in: &self.cancellables)
        }

        var stepStreamCancellable: AnyCancellable?

        if !allowStepWhenDismissed {
            presentable.dismissed
                .prefix(1)
                .sink { _ in
                    context.isDismissed = true
                    stepStreamCancellable?.cancel()
                }
                .store(in: &self.cancellables)
        }

        let forwardStep: (Step) -> Void = { [weak self] step in
            guard !(step is NoneStep) else { return }
            guard allowStepWhenNotPresented || context.isVisible else { return }
            guard !context.isDismissed else { return }
            self?.stepsRelay.accept(step)
        }

        stepper.readyToEmitSteps()
        forwardStep(stepper.initialStep)

        stepStreamCancellable = stepper.steps.sink { step in forwardStep(step) }
        stepStreamCancellable?.store(in: &self.cancellables)
    }

    private func setReadiness(for flow: Flow, basedOn presentables: [Presentable]) {
        let childFlows = presentables.filter { $0 is Flow }.map { $0 as! Flow }

        guard !childFlows.isEmpty else {
            flow.flowReadySubject.accept(true)
            return
        }

        let lock = NSRecursiveLock()
        var readyCount = 0
        let expectedReadyCount = childFlows.count

        childFlows.forEach { childFlow in
            childFlow.flowReadyPublisher
                .prefix(1)
                .sink { [weak flow] _ in
                    lock.lock()
                    readyCount += 1
                    let isReady = readyCount == expectedReadyCount
                    lock.unlock()
                    if isReady { flow?.flowReadySubject.accept(true) }
                }
                .store(in: &self.cancellables)
        }
    }
}

private class PresentableAndStepper {
    let presentable: Presentable
    let stepper: Stepper
    let allowStepWhenNotPresented: Bool
    let allowStepWhenDismissed: Bool

    init(presentable: Presentable, stepper: Stepper,
         allowStepWhenNotPresented: Bool, allowStepWhenDismissed: Bool) {
        self.presentable = presentable
        self.stepper = stepper
        self.allowStepWhenNotPresented = allowStepWhenNotPresented
        self.allowStepWhenDismissed = allowStepWhenDismissed
    }
}

private final class StepStreamContext {
    var isVisible: Bool
    var isDismissed = false
    init(initialVisibility: Bool) { self.isVisible = initialVisibility }
}
#endif
