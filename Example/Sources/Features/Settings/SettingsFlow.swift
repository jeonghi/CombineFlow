import CombineFlow
import SwiftUI
import UIKit

final class SettingsStepper: CombineFlow.Stepper {
    let steps = PublishRelay<Step>()
}

@MainActor
final class SettingsFlow: Flow {
    private weak var navigationController: UINavigationController?
    private let stepper = SettingsStepper()

    var root: Presentable {
        guard let navigationController else {
            fatalError("SettingsFlow navigationController deallocated")
        }
        return navigationController
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? SettingsStep else { return .none }

        switch step {
        case .showSettings:
            let viewController = UIHostingController(rootView: SettingsView(onShowDetail: { [weak self] in
                self?.stepper.steps.accept(SettingsStep.showDetail)
            }))
            viewController.title = "Settings"
            navigationController?.setViewControllers([viewController], animated: false)

            return .one(flowContributor: .contribute(
                withNextPresentable: viewController,
                withNextStepper: stepper
            ))

        case .showDetail:
            let detailViewController = UIHostingController(rootView: FlowDetailView(
                title: "Settings Detail",
                description: "SettingsStep.showDetail를 받아 push로 이동했습니다."
            ))
            detailViewController.title = "Settings Detail"
            navigationController?.pushViewController(detailViewController, animated: true)

            return .one(flowContributor: .contribute(
                withNextPresentable: detailViewController,
                withNextStepper: NoneStepper()
            ))
        }
    }
}
