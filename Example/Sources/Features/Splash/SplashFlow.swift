import CombineFlow
import SwiftUI
import UIKit

final class SplashStepper: Stepper {
    let steps = PublishRelay<Step>()
}

final class SplashFlow: Flow {
    private weak var navigationController: UINavigationController?
    private let stepper = SplashStepper()

    var root: Presentable {
        guard let nav = navigationController else { fatalError() }
        return nav
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? SplashStep else { return .none }
        switch step {
        case .start:
            let vc = UIHostingController(rootView: SplashView())
            vc.navigationItem.hidesBackButton = true
            navigationController?.setViewControllers([vc], animated: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.stepper.steps.accept(SplashStep.completed)
            }

            return .one(flowContributor: .contribute(
                withNextPresentable: vc,
                withNextStepper: stepper
            ))
        case .completed:
            return .end(forwardToParentFlowWithStep: AppStep.login)
        }
    }
}
