import CombineFlow
import SwiftUI
import UIKit

@MainActor
final class SplashFlow: Flow {
    private weak var navigationController: UINavigationController?
    private let stepper = SplashStepper()

    var root: Presentable {
        guard let navigationController else {
            fatalError("SplashFlow navigationController deallocated")
        }
        return navigationController
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? SplashStep else { return .none }

        switch step {
        case .start:
            let viewController = UIHostingController(rootView: SplashView())
            viewController.navigationItem.hidesBackButton = true
            navigationController?.setViewControllers([viewController], animated: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.stepper.steps.accept(SplashStep.completed)
            }

            return .one(flowContributor: .contribute(
                withNextPresentable: viewController,
                withNextStepper: stepper
            ))

        case .completed:
            return .end(forwardToParentFlowWithStep: AppStep.login)
        }
    }
}

final class SplashStepper: CombineFlow.Stepper {
    let steps = PublishRelay<Step>()
}
