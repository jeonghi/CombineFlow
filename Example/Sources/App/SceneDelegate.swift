import CombineFlow
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let coordinator = FlowCoordinator()
    private lazy var appFlow = AppFlow()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        Flows.use([appFlow], when: .created) { (roots: [UINavigationController]) in
            window.rootViewController = roots[0]
            window.makeKeyAndVisible()
        }

        coordinator.coordinate(
            flow: appFlow,
            with: OneStepper(withSingleStep: AppStep.splash)
        )
    }
}
