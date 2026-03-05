import CombineFlow
import ComposableArchitecture
import SwiftUI
import UIKit

final class TCAFlow: Flow {
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
            let store = Store(initialState: TCACounterFeature.State()) {
                TCACounterFeature()
            }
            let vc = UIHostingController(rootView: TCACounterView(store: store))
            navigationController?.setViewControllers([vc], animated: false)
            return .one(flowContributor: .contribute(
                withNextPresentable: vc,
                withNextStepper: NoneStepper()
            ))
        }
    }
}
