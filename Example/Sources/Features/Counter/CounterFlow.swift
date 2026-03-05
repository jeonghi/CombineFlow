import CombineFlow
import UIKit

@MainActor
final class CounterFlow: Flow {
    private weak var navigationController: UINavigationController?
    private let stepper = CounterStepper()

    var root: Presentable {
        guard let nav = navigationController else { fatalError("navigationController is nil") }
        return nav
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? CounterStep else { return .none }

        switch step {
        case .showCounter:
            let vc = CounterViewController(stepper: stepper)
            navigationController?.setViewControllers([vc], animated: false)
            return .one(flowContributor: .contribute(
                withNextPresentable: vc,
                withNextStepper: stepper
            ))
        case .counterDone(let count):
            return .end(forwardToParentFlowWithStep: AppStep.counterCompleted(count: count))
        }
    }
}
