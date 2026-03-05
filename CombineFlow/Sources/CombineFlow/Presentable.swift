// Presentable.swift
// CombineFlow

#if canImport(UIKit)
import Combine
import UIKit.UIViewController

public protocol Presentable {
    var visible: AnyPublisher<Bool, Never> { get }
    var dismissed: AnyPublisher<Void, Never> { get }
}

public extension Presentable where Self: UIViewController {
    var visible: AnyPublisher<Bool, Never> { self.displayedPublisher }

    var dismissed: AnyPublisher<Void, Never> {
        self.dismissedPublisher
            .prefix(1)
            .eraseToAnyPublisher()
    }
}

public extension Presentable where Self: Flow {
    var visible: AnyPublisher<Bool, Never> { self.root.visible }
    var dismissed: AnyPublisher<Void, Never> { self.root.dismissed }
}

public extension Presentable where Self: UIWindow {
    var visible: AnyPublisher<Bool, Never> {
        self.windowDidAppearPublisher
            .map { true }
            .eraseToAnyPublisher()
    }

    var dismissed: AnyPublisher<Void, Never> {
        Empty(completeImmediately: false).eraseToAnyPublisher()
    }
}
#endif
