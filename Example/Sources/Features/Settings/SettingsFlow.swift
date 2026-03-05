import CombineFlow
import SwiftUI
import UIKit

final class SettingsFlow: Flow {
    private weak var navigationController: UINavigationController?

    var root: Presentable {
        guard let nav = navigationController else { fatalError() }
        return nav
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? SettingsStep else { return .none }
        switch step {
        case .showSettings:
            let vc = UIHostingController(rootView: SettingsView())
            navigationController?.setViewControllers([vc], animated: false)
            return .one(flowContributor: .contribute(
                withNextPresentable: vc,
                withNextStepper: NoneStepper()
            ))
        }
    }
}
