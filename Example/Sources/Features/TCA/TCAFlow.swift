import CombineFlow
import ComposableArchitecture
import SwiftUI
import UIKit

final class TCAStepper: CombineFlow.Stepper {
    let steps = PublishRelay<Step>()
}

@MainActor
final class TCAFlow: Flow {
    private weak var navigationController: UINavigationController?
    private let stepper = TCAStepper()

    var root: Presentable {
        guard let navigationController else {
            fatalError("TCAFlow navigationController deallocated")
        }
        return navigationController
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? TCAStep else { return .none }

        switch step {
        case .showCounter:
            let store = Store(initialState: TCACounterFeature.State()) {
                TCACounterFeature()
            }
            let viewController = UIHostingController(
                rootView: TCACounterView(store: store, onShowDetail: { [weak self] in
                    self?.stepper.steps.accept(TCAStep.showDetail)
                })
            )
            viewController.title = "TCA Counter"
            navigationController?.setViewControllers([viewController], animated: false)

            return .one(flowContributor: .contribute(
                withNextPresentable: viewController,
                withNextStepper: stepper
            ))

        case .showDetail:
            let detailViewController = UIHostingController(rootView: FlowDetailView(
                title: "TCA Detail",
                description: "TCAStep.showDetail를 받아 push로 이동했습니다."
            ))
            detailViewController.title = "TCA Detail"
            navigationController?.pushViewController(detailViewController, animated: true)

            return .one(flowContributor: .contribute(
                withNextPresentable: detailViewController,
                withNextStepper: NoneStepper()
            ))
        }
    }
}
