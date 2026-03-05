import CombineFlow
import SwiftUI
import UIKit

final class LoginStepper: CombineFlow.Stepper {
    let steps = PublishRelay<Step>()
}

final class LoginFlow: Flow {
    private weak var navigationController: UINavigationController?
    private let stepper = LoginStepper()

    var root: Presentable {
        guard let nav = navigationController else { fatalError() }
        return nav
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? LoginStep else { return .none }
        switch step {
        case .showLogin:
            let view = LoginView { [weak self] token in
                self?.stepper.steps.accept(LoginStep.loginCompleted(token: token))
            }
            let vc = UIHostingController(rootView: view)
            vc.navigationItem.hidesBackButton = true
            navigationController?.setViewControllers([vc], animated: false)
            return .one(flowContributor: .contribute(
                withNextPresentable: vc,
                withNextStepper: stepper
            ))
        case .loginCompleted(let token):
            return .end(forwardToParentFlowWithStep: AppStep.loginCompleted(token: token))
        }
    }
}
