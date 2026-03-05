import CombineFlow
import SwiftUI
import UIKit

final class LoginStepper: CombineFlow.Stepper {
    let steps = PublishRelay<Step>()
}

@MainActor
final class LoginFlow: Flow {
    private weak var navigationController: UINavigationController?
    private let stepper = LoginStepper()

    var root: Presentable {
        guard let navigationController else {
            fatalError("LoginFlow navigationController deallocated")
        }
        return navigationController
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
            let viewController = UIHostingController(rootView: view)
            viewController.navigationItem.hidesBackButton = true
            navigationController?.setViewControllers([viewController], animated: false)

            return .one(flowContributor: .contribute(
                withNextPresentable: viewController,
                withNextStepper: stepper
            ))

        case .loginCompleted(let token):
            AuthenticationService.shared.login(token: token)
            return .end(forwardToParentFlowWithStep: AppStep.loginCompleted(token: token))
        }
    }
}
