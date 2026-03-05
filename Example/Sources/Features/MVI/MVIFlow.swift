import CombineFlow
import SwiftUI
import UIKit

final class MVIStepper: CombineFlow.Stepper {
    let steps = PublishRelay<Step>()
}

@MainActor
final class MVIFlow: Flow {
    private weak var navigationController: UINavigationController?
    private let stepper = MVIStepper()

    var root: Presentable {
        guard let navigationController else {
            fatalError("MVIFlow navigationController deallocated")
        }
        return navigationController
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? MVIStep else { return .none }

        switch step {
        case .showCounter:
            let viewController = UIHostingController(rootView: MVICounterView(onShowDetail: { [weak self] in
                self?.stepper.steps.accept(MVIStep.showDetail)
            }))
            viewController.title = "MVI Counter"
            navigationController?.setViewControllers([viewController], animated: false)

            return .one(flowContributor: .contribute(
                withNextPresentable: viewController,
                withNextStepper: stepper
            ))

        case .showDetail:
            let detailViewController = UIHostingController(rootView: FlowDetailView(
                title: "MVI Detail",
                description: "MVIStep.showDetail를 받아 push로 이동했습니다."
            ))
            detailViewController.title = "MVI Detail"
            navigationController?.pushViewController(detailViewController, animated: true)

            return .one(flowContributor: .contribute(
                withNextPresentable: detailViewController,
                withNextStepper: NoneStepper()
            ))
        }
    }
}
