// Flow.swift
// CombineFlow

#if canImport(UIKit)
import Combine
import UIKit

private enum FlowAssociatedKeys {
    nonisolated(unsafe) static var subjectContext: UInt8 = 0
}

@MainActor
public protocol Flow: AnyObject, Presentable, Synchronizable {
    var root: Presentable { get }
    func adapt(step: Step) -> AnyPublisher<Step, Never>
    func navigate(to step: Step) -> FlowContributors
}

@MainActor
public extension Flow {
    func adapt(step: Step) -> AnyPublisher<Step, Never> {
        Just(step).eraseToAnyPublisher()
    }
}

extension Flow {
    internal var flowReadySubject: PublishRelay<Bool> {
        self.synchronized {
            if let subject = objc_getAssociatedObject(
                self,
                &FlowAssociatedKeys.subjectContext
            ) as? PublishRelay<Bool> {
                return subject
            }
            let newSubject = PublishRelay<Bool>()
            objc_setAssociatedObject(
                self,
                &FlowAssociatedKeys.subjectContext,
                newSubject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            return newSubject
        }
    }

    internal var flowReadyPublisher: AnyPublisher<Bool, Never> {
        self.flowReadySubject
            .prefix(1)
            .eraseToAnyPublisher()
    }
}

private enum FlowsReadinessStore {
    static let lock = NSRecursiveLock()
    nonisolated(unsafe) static var cancellables = [UUID: AnyCancellable]()

    static func retain(_ cancellable: AnyCancellable, for id: UUID) {
        self.lock.lock()
        self.cancellables[id] = cancellable
        self.lock.unlock()
    }

    static func release(for id: UUID) {
        self.lock.lock()
        self.cancellables.removeValue(forKey: id)
        self.lock.unlock()
    }
}

@MainActor
private extension Flows {
    static func whenReady(_ flows: [Flow], block: @escaping () -> Void) {
        guard !flows.isEmpty else { block(); return }

        let readinessID = UUID()
        let readinessCancellable = Publishers.MergeMany(
            flows.map {
                $0.flowReadyPublisher
                    .prefix(1)
                    .map { _ in () }
                    .eraseToAnyPublisher()
            }
        )
        .collect(flows.count)
        .prefix(1)
        .sink(
            receiveCompletion: { _ in FlowsReadinessStore.release(for: readinessID) },
            receiveValue: { _ in block() }
        )

        FlowsReadinessStore.retain(readinessCancellable, for: readinessID)
    }
}

@MainActor
public enum Flows {
    public enum ExecuteStrategy {
        case ready
        case created
    }

    public static func use<Root: UIViewController>(
        _ flows: [Flow],
        when strategy: ExecuteStrategy,
        block: @escaping ([Root]) -> Void
    ) {
        let roots = flows.compactMap { $0.root as? Root }
        guard roots.count == flows.count else {
            fatalError("Type mismatch, Flows roots types do not match the types awaited in the block")
        }
        switch strategy {
        case .created: block(roots)
        case .ready: self.whenReady(flows) { block(roots) }
        }
    }

    public static func use<Root1: UIViewController, Root2: UIViewController>(
        _ flow1: Flow,
        _ flow2: Flow,
        when strategy: ExecuteStrategy,
        block: @escaping (Root1, Root2) -> Void
    ) {
        guard let root1 = flow1.root as? Root1, let root2 = flow2.root as? Root2 else {
            fatalError("Type mismatch, Flows roots types do not match the types awaited in the block")
        }
        switch strategy {
        case .created: block(root1, root2)
        case .ready: self.whenReady([flow1, flow2]) { block(root1, root2) }
        }
    }

    public static func use<Root1: UIViewController, Root2: UIViewController, Root3: UIViewController>(
        _ flow1: Flow,
        _ flow2: Flow,
        _ flow3: Flow,
        when strategy: ExecuteStrategy,
        block: @escaping (Root1, Root2, Root3) -> Void
    ) {
        guard
            let root1 = flow1.root as? Root1,
            let root2 = flow2.root as? Root2,
            let root3 = flow3.root as? Root3
        else {
            fatalError("Type mismatch, Flows roots types do not match the types awaited in the block")
        }
        switch strategy {
        case .created: block(root1, root2, root3)
        case .ready: self.whenReady([flow1, flow2, flow3]) { block(root1, root2, root3) }
        }
    }
}
#endif
