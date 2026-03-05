import CombineFlow
import UIKit

final class MainFlow: Flow {
    private let tabBarController = UITabBarController()

    var root: Presentable { tabBarController }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? MainStep else { return .none }
        switch step {
        case .showMain:
            return setupTabs()
        }
    }

    private func setupTabs() -> FlowContributors {
        let mvvmNav = UINavigationController()
        mvvmNav.tabBarItem = UITabBarItem(title: "MVVM", image: UIImage(systemName: "1.circle"), tag: 0)

        let tcaNav = UINavigationController()
        tcaNav.tabBarItem = UITabBarItem(title: "TCA", image: UIImage(systemName: "2.circle"), tag: 1)

        let mviNav = UINavigationController()
        mviNav.tabBarItem = UITabBarItem(title: "MVI", image: UIImage(systemName: "3.circle"), tag: 2)

        let reactorNav = UINavigationController()
        reactorNav.tabBarItem = UITabBarItem(title: "Reactor", image: UIImage(systemName: "4.circle"), tag: 3)

        let settingsNav = UINavigationController()
        settingsNav.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"), tag: 4)

        tabBarController.setViewControllers(
            [mvvmNav, tcaNav, mviNav, reactorNav, settingsNav],
            animated: false
        )

        let mvvmFlow = MVVMFlow(navigationController: mvvmNav)
        let tcaFlow = TCAFlow(navigationController: tcaNav)
        let mviFlow = MVIFlow(navigationController: mviNav)
        let reactorFlow = ReactorFlow(navigationController: reactorNav)
        let settingsFlow = SettingsFlow(navigationController: settingsNav)

        return .multiple(flowContributors: [
            .contribute(
                withNextPresentable: mvvmFlow,
                withNextStepper: OneStepper(withSingleStep: CounterStep.showCounter)
            ),
            .contribute(
                withNextPresentable: tcaFlow,
                withNextStepper: OneStepper(withSingleStep: CounterStep.showCounter)
            ),
            .contribute(
                withNextPresentable: mviFlow,
                withNextStepper: OneStepper(withSingleStep: CounterStep.showCounter)
            ),
            .contribute(
                withNextPresentable: reactorFlow,
                withNextStepper: OneStepper(withSingleStep: CounterStep.showCounter)
            ),
            .contribute(
                withNextPresentable: settingsFlow,
                withNextStepper: OneStepper(withSingleStep: SettingsStep.showSettings)
            ),
        ])
    }
}
