import CombineFlow
import UIKit

final class AppFlow: Flow {
    private let navigationController = UINavigationController()

    var root: Presentable { navigationController }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? AppStep else { return .none }
        switch step {
        case .splash:
            return navigateToSplash()
        case .login:
            return navigateToLogin()
        case .loginCompleted, .main:
            return navigateToMain()
        }
    }

    private func navigateToSplash() -> FlowContributors {
        let flow = SplashFlow(navigationController: navigationController)
        return .one(flowContributor: .contribute(
            withNextPresentable: flow,
            withNextStepper: OneStepper(withSingleStep: SplashStep.start)
        ))
    }

    private func navigateToLogin() -> FlowContributors {
        let flow = LoginFlow(navigationController: navigationController)
        return .one(flowContributor: .contribute(
            withNextPresentable: flow,
            withNextStepper: OneStepper(withSingleStep: LoginStep.showLogin)
        ))
    }

    private func navigateToMain() -> FlowContributors {
        let flow = MainFlow()
        return .one(flowContributor: .contribute(
            withNextPresentable: flow,
            withNextStepper: OneStepper(withSingleStep: MainStep.showMain)
        ))
    }
}
