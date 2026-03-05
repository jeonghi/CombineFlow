import CombineFlow
import SwiftUI
import UIKit

final class ReactorFlow: Flow {
    private weak var navigationController: UINavigationController?

    var root: Presentable {
        guard let nav = navigationController else { fatalError() }
        return nav
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? CounterStep else { return .none }
        switch step {
        case .showCounter:
            let vc = UIHostingController(rootView: ReactorCounterView())
            navigationController?.setViewControllers([vc], animated: false)
            return .one(flowContributor: .contribute(
                withNextPresentable: vc,
                withNextStepper: NoneStepper()
            ))
        }
    }
}
