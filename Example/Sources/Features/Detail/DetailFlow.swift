import CombineFlow
import SwiftUI
import UIKit

final class DetailStepper: CombineFlow.Stepper {
    let steps = PublishRelay<Step>()
    func dismiss() { steps.accept(DetailStep.dismiss) }
}

final class DetailFlow: Flow {
    private weak var navigationController: UINavigationController?
    private let stepper = DetailStepper()

    var root: Presentable {
        guard let nav = navigationController else { fatalError("navigationController is nil") }
        return nav
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? DetailStep else { return .none }

        switch step {
        case .showDetail(let count):
            let view = DetailView(count: count) { [weak self] in
                self?.stepper.dismiss()
            }
            let hostingVC = UIHostingController(rootView: view)
            navigationController?.pushViewController(hostingVC, animated: true)
            return .one(flowContributor: .contribute(
                withNextPresentable: hostingVC,
                withNextStepper: stepper
            ))
        case .dismiss:
            navigationController?.popViewController(animated: true)
            return .end(forwardToParentFlowWithStep: AppStep.counterRequested)
        }
    }
}
