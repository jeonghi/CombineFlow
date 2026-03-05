import CombineFlow
import SwiftUI
import UIKit

final class MVVMStepper: CombineFlow.Stepper {
    let steps = PublishRelay<Step>()
}

@MainActor
final class MVVMFlow: Flow {
    private weak var navigationController: UINavigationController?
    private let stepper = MVVMStepper()

    var root: Presentable {
        guard let navigationController else {
            fatalError("MVVMFlow navigationController deallocated")
        }
        return navigationController
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? MVVMStep else { return .none }

        switch step {
        case .showCounter:
            let viewController = UIHostingController(rootView: MVVMCounterView(onShowDetail: { [weak self] in
                self?.stepper.steps.accept(MVVMStep.showDetail)
            }))
            viewController.title = "MVVM Counter"
            navigationController?.setViewControllers([viewController], animated: false)

            return .one(flowContributor: .contribute(
                withNextPresentable: viewController,
                withNextStepper: stepper
            ))

        case .showDetail:
            let detailViewController = UIHostingController(rootView: FlowDetailView(
                title: "MVVM Detail",
                description: "MVVMStep.showDetail를 받아 push로 이동했습니다."
            ))
            detailViewController.title = "MVVM Detail"
            navigationController?.pushViewController(detailViewController, animated: true)

            return .one(flowContributor: .contribute(
                withNextPresentable: detailViewController,
                withNextStepper: NoneStepper()
            ))
        }
    }
}
