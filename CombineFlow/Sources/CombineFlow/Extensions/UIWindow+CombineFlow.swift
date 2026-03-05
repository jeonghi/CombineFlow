// UIWindow+CombineFlow.swift
// CombineFlow

#if canImport(UIKit)
import Combine
import ObjectiveC
import UIKit.UIWindow

private final class UIWindowLifecyclePublisher {
    let didAppear = PassthroughSubject<Void, Never>()
}

private enum UIWindowLifecycleAssociatedKeys {
    nonisolated(unsafe) static var lifecyclePublisher: UInt8 = 0
}

private enum UIWindowLifecycleSwizzler {
    static let swizzleImplementation: Void = {
        swizzle(
            UIWindow.self,
            #selector(UIWindow.makeKeyAndVisible),
            #selector(UIWindow.combineflow_makeKeyAndVisible)
        )
    }()
}

public extension UIWindow {
    var windowDidAppearPublisher: AnyPublisher<Void, Never> {
        self.combineflowLifecyclePublisher.didAppear.eraseToAnyPublisher()
    }

    private var combineflowLifecyclePublisher: UIWindowLifecyclePublisher {
        _ = UIWindowLifecycleSwizzler.swizzleImplementation

        if let publisher = objc_getAssociatedObject(
            self,
            &UIWindowLifecycleAssociatedKeys.lifecyclePublisher
        ) as? UIWindowLifecyclePublisher {
            return publisher
        }

        let publisher = UIWindowLifecyclePublisher()
        objc_setAssociatedObject(
            self,
            &UIWindowLifecycleAssociatedKeys.lifecyclePublisher,
            publisher,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return publisher
    }

    @objc func combineflow_makeKeyAndVisible() {
        self.combineflow_makeKeyAndVisible()
        self.combineflowLifecyclePublisher.didAppear.send(())
    }
}

extension UIWindow: Presentable {}

private func swizzle(_ cls: AnyClass, _ originalSelector: Selector, _ swizzledSelector: Selector) {
    guard
        let originalMethod = class_getInstanceMethod(cls, originalSelector),
        let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector)
    else { return }

    let didAddMethod = class_addMethod(
        cls, originalSelector,
        method_getImplementation(swizzledMethod),
        method_getTypeEncoding(swizzledMethod)
    )

    if didAddMethod {
        class_replaceMethod(
            cls, swizzledSelector,
            method_getImplementation(originalMethod),
            method_getTypeEncoding(originalMethod)
        )
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}
#endif
