// UIViewController+CombineFlow.swift
// CombineFlow

#if canImport(UIKit)
import Combine
import ObjectiveC
import UIKit.UIViewController

private final class UIViewControllerLifecyclePublisher {
    let displayed: CurrentValueSubject<Bool, Never>
    let dismissed = PassthroughSubject<Void, Never>()

    init(initiallyDisplayed: Bool) {
        self.displayed = CurrentValueSubject(initiallyDisplayed)
    }
}

private enum UIViewControllerLifecycleAssociatedKeys {
    nonisolated(unsafe) static var lifecyclePublisher: UInt8 = 0
}

private enum UIViewControllerLifecycleSwizzler {
    static let swizzleImplementation: Void = {
        swizzle(
            UIViewController.self,
            #selector(UIViewController.viewDidAppear(_:)),
            #selector(UIViewController.combineflow_viewDidAppear(_:))
        )
        swizzle(
            UIViewController.self,
            #selector(UIViewController.viewDidDisappear(_:)),
            #selector(UIViewController.combineflow_viewDidDisappear(_:))
        )
        swizzle(
            UIViewController.self,
            #selector(UIViewController.didMove(toParent:)),
            #selector(UIViewController.combineflow_didMove(toParent:))
        )
    }()
}

public extension UIViewController {
    var displayedPublisher: AnyPublisher<Bool, Never> {
        self.combineflowLifecyclePublisher.displayed.eraseToAnyPublisher()
    }

    var dismissedPublisher: AnyPublisher<Void, Never> {
        self.combineflowLifecyclePublisher.dismissed.eraseToAnyPublisher()
    }

    private var combineflowLifecyclePublisher: UIViewControllerLifecyclePublisher {
        _ = UIViewControllerLifecycleSwizzler.swizzleImplementation

        if let publisher = objc_getAssociatedObject(
            self,
            &UIViewControllerLifecycleAssociatedKeys.lifecyclePublisher
        ) as? UIViewControllerLifecyclePublisher {
            return publisher
        }

        let publisher = UIViewControllerLifecyclePublisher(
            initiallyDisplayed: self.viewIfLoaded?.window != nil
        )
        objc_setAssociatedObject(
            self,
            &UIViewControllerLifecycleAssociatedKeys.lifecyclePublisher,
            publisher,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return publisher
    }

    @objc func combineflow_viewDidAppear(_ animated: Bool) {
        self.combineflow_viewDidAppear(animated)
        self.combineflowLifecyclePublisher.displayed.send(true)
    }

    @objc func combineflow_viewDidDisappear(_ animated: Bool) {
        self.combineflow_viewDidDisappear(animated)
        self.combineflowLifecyclePublisher.displayed.send(false)

        if self.isBeingDismissed || self.navigationController?.isBeingDismissed == true {
            self.combineflowLifecyclePublisher.dismissed.send(())
        }
    }

    @objc func combineflow_didMove(toParent parent: UIViewController?) {
        self.combineflow_didMove(toParent: parent)
        if parent == nil {
            self.combineflowLifecyclePublisher.dismissed.send(())
        }
    }
}

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
