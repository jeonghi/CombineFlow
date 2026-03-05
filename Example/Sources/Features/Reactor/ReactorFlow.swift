import CombineFlow
import SwiftUI
import UIKit

final class ReactorStepper: CombineFlow.Stepper {
    let steps = PublishRelay<Step>()
}

@MainActor
final class ReactorFlow: Flow {
    private weak var navigationController: UINavigationController?
    private let stepper = ReactorStepper()

    var root: Presentable {
        guard let navigationController else {
            fatalError("ReactorFlow navigationController deallocated")
        }
        return navigationController
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? ReactorStep else { return .none }

        switch step {
        case .showCounter:
            let viewController = UIHostingController(rootView: ReactorCounterView(onShowDetail: { [weak self] in
                self?.stepper.steps.accept(ReactorStep.showDetail)
            }))
            viewController.title = "Reactor Counter"
            navigationController?.setViewControllers([viewController], animated: false)

            return .one(flowContributor: .contribute(
                withNextPresentable: viewController,
                withNextStepper: stepper
            ))

        case .showDetail:
            let detailViewController = UIHostingController(rootView: FlowDetailView(
                title: "Reactor Detail",
                description: "ReactorStep.showDetail를 받아 push로 이동했습니다."
            ))
            detailViewController.title = "Reactor Detail"
            navigationController?.pushViewController(detailViewController, animated: true)

            return .one(flowContributor: .contribute(
                withNextPresentable: detailViewController,
                withNextStepper: NoneStepper()
            ))
        }
    }
}
