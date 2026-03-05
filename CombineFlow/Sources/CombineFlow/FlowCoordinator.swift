// FlowCoordinator.swift
// CombineFlow

#if canImport(UIKit)
import Combine
import Foundation

@MainActor
public final class FlowCoordinator: NSObject {
    private var cancellables = Set<AnyCancellable>()
    private var stepAdaptationCancellables = [UUID: AnyCancellable]()
    private var stepAdaptationWatchdogs = [UUID: DispatchWorkItem]()
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

    /// `adapt(step:)`가 값을 방출하지 않을 때 pending adaptation을 취소하는 watchdog 간격(초).
    /// 0 이하로 설정하면 watchdog을 비활성화합니다.
    public static var adaptationWatchdogInterval: TimeInterval = 5

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
        let adaptationID = UUID()
        let adaptationCancellable = flow.adapt(step: step)
            .prefix(1)
            .sink(
                receiveCompletion: { [weak self] _ in
                    self?.clearAdaptationTracking(for: adaptationID)
                },
                receiveValue: { [weak self] adaptedStep in
                    guard let self else { return }
                    self.willNavigateRelay.accept((flow, adaptedStep))
                    let flowContributors = flow.navigate(to: adaptedStep)
                    self.didNavigateRelay.accept((flow, adaptedStep))
                    self.handle(flowContributors: flowContributors, in: flow)
                }
            )
        self.stepAdaptationCancellables[adaptationID] = adaptationCancellable
        self.scheduleAdaptationWatchdog(for: adaptationID)
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
        self.stepAdaptationCancellables.values.forEach { $0.cancel() }
        self.stepAdaptationCancellables.removeAll()
        self.stepAdaptationWatchdogs.values.forEach { $0.cancel() }
        self.stepAdaptationWatchdogs.removeAll()
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

        let dismissalSignal: AnyPublisher<Void, Never>
        if allowStepWhenDismissed {
            dismissalSignal = Empty<Void, Never>(completeImmediately: false).eraseToAnyPublisher()
        } else {
            dismissalSignal = presentable.dismissed
                .prefix(1)
                .handleEvents(receiveOutput: { _ in context.isDismissed = true })
                .eraseToAnyPublisher()
        }

        let forwardStep: (Step) -> Void = { [weak self] step in
            guard !(step is NoneStep) else { return }
            guard allowStepWhenNotPresented || context.isVisible else { return }
            guard !context.isDismissed else { return }
            self?.stepsRelay.accept(step)
        }

        stepper.steps
            .prefix(untilOutputFrom: dismissalSignal)
            .sink { step in forwardStep(step) }
            .store(in: &self.cancellables)

        stepper.readyToEmitSteps()
        forwardStep(stepper.initialStep)
    }

    private func setReadiness(for flow: Flow, basedOn presentables: [Presentable]) {
        let childFlows = presentables.filter { $0 is Flow }.map { $0 as! Flow }

        guard !childFlows.isEmpty else {
            flow.flowReadySubject.send(true)
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
                    if isReady { flow?.flowReadySubject.send(true) }
                }
                .store(in: &self.cancellables)
        }
    }

    private func scheduleAdaptationWatchdog(for adaptationID: UUID) {
        guard Self.adaptationWatchdogInterval > 0 else { return }

        let watchdog = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard let cancellable = self.stepAdaptationCancellables[adaptationID] else { return }

            cancellable.cancel()
            self.clearAdaptationTracking(for: adaptationID)
        }

        self.stepAdaptationWatchdogs[adaptationID] = watchdog
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.adaptationWatchdogInterval,
            execute: watchdog
        )
    }

    private func clearAdaptationTracking(for adaptationID: UUID) {
        self.stepAdaptationCancellables.removeValue(forKey: adaptationID)
        self.stepAdaptationWatchdogs.removeValue(forKey: adaptationID)?.cancel()
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
