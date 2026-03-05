import UIKit

final class TabNavigationController: UINavigationController {
    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        for (index, viewController) in viewControllers.enumerated() {
            viewController.hidesBottomBarWhenPushed = index > 0
        }
        super.setViewControllers(viewControllers, animated: animated)
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        viewController.hidesBottomBarWhenPushed = !viewControllers.isEmpty
        super.pushViewController(viewController, animated: animated)
    }
}
