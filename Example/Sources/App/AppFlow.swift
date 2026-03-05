import CombineFlow
import UIKit

final class AppFlow: Flow {
    private let navigationController = UINavigationController()

    var root: Presentable { navigationController }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? AppStep else { return .none }

        switch step {
        case .counterRequested:
            return navigateToCounter()
        case .counterCompleted(let count):
            return navigateToDetail(count: count)
        }
    }

    private func navigateToCounter() -> FlowContributors {
        let counterFlow = CounterFlow(navigationController: navigationController)
        return .one(flowContributor: .contribute(
            withNextPresentable: counterFlow,
            withNextStepper: OneStepper(withSingleStep: CounterStep.showCounter)
        ))
    }

    private func navigateToDetail(count: Int) -> FlowContributors {
        let detailFlow = DetailFlow(navigationController: navigationController)
        return .one(flowContributor: .contribute(
            withNextPresentable: detailFlow,
            withNextStepper: OneStepper(withSingleStep: DetailStep.showDetail(count: count))
        ))
    }
}
