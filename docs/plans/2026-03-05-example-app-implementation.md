# CombineFlow Example App 확장 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** CombineFlowExample에 Splash→Login→MainTabBar(4탭) 구조를 추가하고, 동일한 카운터를 MVVM/TCA/MVI/Reactor 4가지 패턴으로 각 탭에 구현한다.

**Architecture:** AppFlow가 Splash→Login→Main을 순서대로 조율한다. MainFlow는 UITabBarController를 root로 하며 4개의 자식 Flow를 관리한다. 각 탭은 동일한 카운터(+1/-1/reset, 값 표시)를 서로 다른 아키텍처로 구현한다.

**Tech Stack:** Swift 6.0, iOS 17+, CombineFlow (로컬), ComposableArchitecture 1.10+, SwiftUI, UIKit(TabBar/Hosting)

---

## 사전 준비 — 삭제 및 의존성 추가

### Task 1: 기존 Counter/Detail 폴더 삭제 + Project.swift TCA 의존성 추가

**Files:**
- Delete: `~/LodyProjects/CombineFlow/Example/Sources/Features/Counter/`
- Delete: `~/LodyProjects/CombineFlow/Example/Sources/Features/Detail/`
- Modify: `~/LodyProjects/CombineFlow/Example/Project.swift`

**Step 1: 기존 Feature 폴더 삭제**

```bash
rm -rf ~/LodyProjects/CombineFlow/Example/Sources/Features/Counter
rm -rf ~/LodyProjects/CombineFlow/Example/Sources/Features/Detail
```

**Step 2: `Example/Project.swift` 전체 교체**

```swift
import ProjectDescription

let project = Project(
    name: "CombineFlowExample",
    options: .options(automaticSchemesOptions: .enabled()),
    packages: [
        .remote(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            requirement: .upToNextMajor(from: "1.10.0")
        )
    ],
    targets: [
        .target(
            name: "CombineFlowExample",
            destinations: .iOS,
            product: .app,
            bundleId: "io.combineflow.Example",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "CFBundleDisplayName": "CombineFlowExample",
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": false,
                    "UISceneConfigurations": [
                        "UIWindowSceneSessionRoleApplication": [
                            [
                                "UISceneConfigurationName": "Default Configuration",
                                "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).SceneDelegate"
                            ]
                        ]
                    ]
                ]
            ]),
            buildableFolders: ["Sources"],
            dependencies: [
                .project(target: "CombineFlow", path: "../CombineFlow"),
                .package(product: "ComposableArchitecture")
            ],
            settings: .settings(base: [
                "SWIFT_VERSION": "6.0"
            ])
        )
    ]
)
```

**Step 3: tuist install (TCA 패키지 resolve)**

```bash
cd ~/LodyProjects/CombineFlow
tuist install
```

Expected: `swift-composable-architecture` resolve 완료

**Step 4: 커밋**

```bash
cd ~/LodyProjects/CombineFlow
git add Example/Project.swift
git rm -r --cached Example/Sources/Features/Counter Example/Sources/Features/Detail 2>/dev/null || true
git commit -m "chore: add TCA dependency, remove old Counter/Detail features"
```

---

## App 레이어 교체

### Task 2: AppStep / AppFlow 전면 교체

**Files:**
- Modify: `~/LodyProjects/CombineFlow/Example/Sources/App/AppStep.swift`
- Modify: `~/LodyProjects/CombineFlow/Example/Sources/App/AppFlow.swift`
- Modify: `~/LodyProjects/CombineFlow/Example/Sources/App/SceneDelegate.swift`

**Step 1: `AppStep.swift` 교체**

```swift
// AppStep.swift
import CombineFlow

enum AppStep: Step {
    case splash
    case login
    case loginCompleted(token: String)
    case main
}
```

**Step 2: `AppFlow.swift` 교체**

```swift
// AppFlow.swift
import CombineFlow
import UIKit

final class AppFlow: Flow {
    private let navigationController = UINavigationController()

    var root: Presentable { navigationController }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? AppStep else { return .none }
        switch step {
        case .splash:
            return navigateToSplash()
        case .login:
            return navigateToLogin()
        case .loginCompleted:
            return navigateToMain()
        case .main:
            return navigateToMain()
        }
    }

    private func navigateToSplash() -> FlowContributors {
        let flow = SplashFlow(navigationController: navigationController)
        return .one(flowContributor: .contribute(
            withNextPresentable: flow,
            withNextStepper: OneStepper(withSingleStep: SplashStep.start)
        ))
    }

    private func navigateToLogin() -> FlowContributors {
        let flow = LoginFlow(navigationController: navigationController)
        return .one(flowContributor: .contribute(
            withNextPresentable: flow,
            withNextStepper: OneStepper(withSingleStep: LoginStep.showLogin)
        ))
    }

    private func navigateToMain() -> FlowContributors {
        let flow = MainFlow()
        return .one(flowContributor: .contribute(
            withNextPresentable: flow,
            withNextStepper: OneStepper(withSingleStep: MainStep.showMain)
        ))
    }
}
```

**Step 3: `SceneDelegate.swift` 교체**

```swift
// SceneDelegate.swift
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
```

**Step 4: 커밋**

```bash
cd ~/LodyProjects/CombineFlow
git add Example/Sources/App/
git commit -m "feat: replace AppStep/AppFlow with Splash→Login→Main flow"
```

---

## Splash

### Task 3: SplashFlow + SplashView

**Files:**
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/Splash/SplashStep.swift`
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/Splash/SplashView.swift`
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/Splash/SplashFlow.swift`

**Step 1: 디렉토리 생성**

```bash
mkdir -p ~/LodyProjects/CombineFlow/Example/Sources/Features/Splash
```

**Step 2: `SplashStep.swift`**

```swift
// SplashStep.swift
import CombineFlow

enum SplashStep: Step {
    case start
    case completed
}
```

**Step 3: `SplashView.swift`**

```swift
// SplashView.swift
import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("⚡")
                    .font(.system(size: 64))
                Text("CombineFlow")
                    .font(.largeTitle.bold())
                Text("Architecture Examples")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

**Step 4: `SplashFlow.swift`**

```swift
// SplashFlow.swift
import CombineFlow
import Combine
import SwiftUI
import UIKit

final class SplashFlow: Flow {
    private weak var navigationController: UINavigationController?
    private var cancellables = Set<AnyCancellable>()
    private let stepper = SplashStepper()

    var root: Presentable {
        guard let nav = navigationController else { fatalError() }
        return nav
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? SplashStep else { return .none }
        switch step {
        case .start:
            let vc = UIHostingController(rootView: SplashView())
            vc.navigationItem.hidesBackButton = true
            navigationController?.setViewControllers([vc], animated: false)

            // 2초 후 login으로 이동
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.stepper.steps.accept(SplashStep.completed)
            }

            return .one(flowContributor: .contribute(
                withNextPresentable: vc,
                withNextStepper: stepper
            ))
        case .completed:
            return .end(forwardToParentFlowWithStep: AppStep.login)
        }
    }
}

final class SplashStepper: Stepper {
    let steps = PublishRelay<Step>()
}
```

**Step 5: 커밋**

```bash
cd ~/LodyProjects/CombineFlow
git add Example/Sources/Features/Splash/
git commit -m "feat: add SplashFlow with 2s auto-transition"
```

---

## Login

### Task 4: LoginFlow + LoginView

**Files:**
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/Login/LoginStep.swift`
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/Login/LoginView.swift`
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/Login/LoginFlow.swift`

**Step 1: 디렉토리 생성**

```bash
mkdir -p ~/LodyProjects/CombineFlow/Example/Sources/Features/Login
```

**Step 2: `LoginStep.swift`**

```swift
// LoginStep.swift
import CombineFlow

enum LoginStep: Step {
    case showLogin
    case loginCompleted(token: String)
}
```

**Step 3: `LoginView.swift`**

```swift
// LoginView.swift
import SwiftUI

struct LoginView: View {
    let onLogin: (String) -> Void

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                VStack(spacing: 8) {
                    Text("⚡")
                        .font(.system(size: 56))
                    Text("CombineFlow")
                        .font(.largeTitle.bold())
                    Text("Architecture Examples")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    let token = UUID().uuidString
                    onLogin(token)
                } label: {
                    Text("로그인")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}
```

**Step 4: `LoginFlow.swift`**

```swift
// LoginFlow.swift
import CombineFlow
import SwiftUI
import UIKit

final class LoginStepper: Stepper {
    let steps = PublishRelay<Step>()
}

final class LoginFlow: Flow {
    private weak var navigationController: UINavigationController?
    private let stepper = LoginStepper()

    var root: Presentable {
        guard let nav = navigationController else { fatalError() }
        return nav
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? LoginStep else { return .none }
        switch step {
        case .showLogin:
            let view = LoginView { [weak self] token in
                self?.stepper.steps.accept(LoginStep.loginCompleted(token: token))
            }
            let vc = UIHostingController(rootView: view)
            vc.navigationItem.hidesBackButton = true
            navigationController?.setViewControllers([vc], animated: false)
            return .one(flowContributor: .contribute(
                withNextPresentable: vc,
                withNextStepper: stepper
            ))
        case .loginCompleted(let token):
            return .end(forwardToParentFlowWithStep: AppStep.loginCompleted(token: token))
        }
    }
}
```

**Step 5: 커밋**

```bash
cd ~/LodyProjects/CombineFlow
git add Example/Sources/Features/Login/
git commit -m "feat: add LoginFlow with mock token generation"
```

---

## Main TabBar

### Task 5: MainFlow (UITabBarController)

**Files:**
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/Main/MainStep.swift`
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/Main/MainFlow.swift`

**Step 1: 디렉토리 생성**

```bash
mkdir -p ~/LodyProjects/CombineFlow/Example/Sources/Features/Main
```

**Step 2: `MainStep.swift`**

```swift
// MainStep.swift
import CombineFlow

enum MainStep: Step {
    case showMain
}
```

**Step 3: `MainFlow.swift`**

```swift
// MainFlow.swift
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

        tabBarController.setViewControllers(
            [mvvmNav, tcaNav, mviNav, reactorNav],
            animated: false
        )

        let mvvmFlow = MVVMFlow(navigationController: mvvmNav)
        let tcaFlow = TCAFlow(navigationController: tcaNav)
        let mviFlow = MVIFlow(navigationController: mviNav)
        let reactorFlow = ReactorFlow(navigationController: reactorNav)

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
        ])
    }
}
```

**Step 4: 공통 CounterStep (4개 탭이 모두 사용)**

`~/LodyProjects/CombineFlow/Example/Sources/Features/Main/CounterStep.swift` 생성:

```swift
// CounterStep.swift
import CombineFlow

/// 4개 탭이 공통으로 사용하는 Step
enum CounterStep: Step {
    case showCounter
}
```

**Step 5: 커밋**

```bash
cd ~/LodyProjects/CombineFlow
git add Example/Sources/Features/Main/
git commit -m "feat: add MainFlow with 4-tab UITabBarController"
```

---

## Tab 1: MVVM

### Task 6: MVVMFlow + ViewModel + View

**Files:**
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/MVVM/MVVMCounterViewModel.swift`
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/MVVM/MVVMCounterView.swift`
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/MVVM/MVVMFlow.swift`

**Step 1: 디렉토리 생성**

```bash
mkdir -p ~/LodyProjects/CombineFlow/Example/Sources/Features/MVVM
```

**Step 2: `MVVMCounterViewModel.swift`**

```swift
// MVVMCounterViewModel.swift
import Combine
import Foundation

@MainActor
final class MVVMCounterViewModel: ObservableObject {
    @Published private(set) var count = 0

    func increment() { count += 1 }
    func decrement() { count -= 1 }
    func reset() { count = 0 }
}
```

**Step 3: `MVVMCounterView.swift`**

```swift
// MVVMCounterView.swift
import SwiftUI

struct MVVMCounterView: View {
    @StateObject private var viewModel = MVVMCounterViewModel()

    var body: some View {
        CounterLayout(
            title: "MVVM",
            subtitle: "ViewModel + @Published",
            count: viewModel.count,
            onIncrement: viewModel.increment,
            onDecrement: viewModel.decrement,
            onReset: viewModel.reset
        )
    }
}
```

**Step 4: `MVVMFlow.swift`**

```swift
// MVVMFlow.swift
import CombineFlow
import SwiftUI
import UIKit

final class MVVMFlow: Flow {
    private weak var navigationController: UINavigationController?

    var root: Presentable {
        guard let nav = navigationController else { fatalError() }
        return nav
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? CounterStep else { return .none }
        switch step {
        case .showCounter:
            let vc = UIHostingController(rootView: MVVMCounterView())
            navigationController?.setViewControllers([vc], animated: false)
            return .one(flowContributor: .contribute(
                withNextPresentable: vc,
                withNextStepper: NoneStepper()
            ))
        }
    }
}
```

**Step 5: 공통 CounterLayout 컴포넌트 생성**

`~/LodyProjects/CombineFlow/Example/Sources/Features/Shared/CounterLayout.swift`:

```swift
// CounterLayout.swift
// 4개 탭이 공통으로 사용하는 카운터 UI 레이아웃
import SwiftUI

struct CounterLayout: View {
    let title: String
    let subtitle: String
    let count: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 아키텍처 뱃지
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            Spacer()

            // 카운터
            Text("\(count)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: count)

            Spacer()

            // 버튼
            HStack(spacing: 24) {
                CircleButton(symbol: "minus", color: .red) { onDecrement() }
                CircleButton(symbol: "arrow.counterclockwise", color: .gray) { onReset() }
                CircleButton(symbol: "plus", color: .green) { onIncrement() }
            }
            .padding(.bottom, 48)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CircleButton: View {
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(color)
                .clipShape(Circle())
                .shadow(color: color.opacity(0.4), radius: 8, y: 4)
        }
    }
}
```

**Step 6: Shared 디렉토리 생성**

```bash
mkdir -p ~/LodyProjects/CombineFlow/Example/Sources/Features/Shared
```

**Step 7: 커밋**

```bash
cd ~/LodyProjects/CombineFlow
git add Example/Sources/Features/MVVM/ Example/Sources/Features/Shared/
git commit -m "feat: add MVVMFlow with ViewModel+Combine pattern"
```

---

## Tab 2: TCA

### Task 7: TCAFlow + CounterFeature + View

**Files:**
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/TCA/TCACounterFeature.swift`
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/TCA/TCACounterView.swift`
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/TCA/TCAFlow.swift`

**Step 1: 디렉토리 생성**

```bash
mkdir -p ~/LodyProjects/CombineFlow/Example/Sources/Features/TCA
```

**Step 2: `TCACounterFeature.swift`**

```swift
// TCACounterFeature.swift
import ComposableArchitecture

@Reducer
struct TCACounterFeature {
    @ObservableState
    struct State: Equatable {
        var count = 0
    }

    enum Action {
        case increment
        case decrement
        case reset
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .increment:
                state.count += 1
                return .none
            case .decrement:
                state.count -= 1
                return .none
            case .reset:
                state.count = 0
                return .none
            }
        }
    }
}
```

**Step 3: `TCACounterView.swift`**

```swift
// TCACounterView.swift
import ComposableArchitecture
import SwiftUI

struct TCACounterView: View {
    @Bindable var store: StoreOf<TCACounterFeature>

    var body: some View {
        CounterLayout(
            title: "TCA",
            subtitle: "Reducer + Store",
            count: store.count,
            onIncrement: { store.send(.increment) },
            onDecrement: { store.send(.decrement) },
            onReset: { store.send(.reset) }
        )
    }
}
```

**Step 4: `TCAFlow.swift`**

```swift
// TCAFlow.swift
import CombineFlow
import ComposableArchitecture
import SwiftUI
import UIKit

final class TCAFlow: Flow {
    private weak var navigationController: UINavigationController?

    var root: Presentable {
        guard let nav = navigationController else { fatalError() }
        return nav
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? CounterStep else { return .none }
        switch step {
        case .showCounter:
            let store = Store(initialState: TCACounterFeature.State()) {
                TCACounterFeature()
            }
            let vc = UIHostingController(rootView: TCACounterView(store: store))
            navigationController?.setViewControllers([vc], animated: false)
            return .one(flowContributor: .contribute(
                withNextPresentable: vc,
                withNextStepper: NoneStepper()
            ))
        }
    }
}
```

**Step 5: 커밋**

```bash
cd ~/LodyProjects/CombineFlow
git add Example/Sources/Features/TCA/
git commit -m "feat: add TCAFlow with Reducer+Store pattern"
```

---

## Tab 3: MVI

### Task 8: MVIFlow + Model + View

단방향 Intent → Model(상태 변환) → View 패턴. ObservableObject + 열거형 Intent.

**Files:**
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/MVI/MVICounterModel.swift`
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/MVI/MVICounterView.swift`
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/MVI/MVIFlow.swift`

**Step 1: 디렉토리 생성**

```bash
mkdir -p ~/LodyProjects/CombineFlow/Example/Sources/Features/MVI
```

**Step 2: `MVICounterModel.swift`**

```swift
// MVICounterModel.swift
import Combine
import Foundation

@MainActor
final class MVICounterModel: ObservableObject {
    // State
    @Published private(set) var count = 0

    // Intent
    enum Intent {
        case increment
        case decrement
        case reset
    }

    func process(_ intent: Intent) {
        switch intent {
        case .increment: count += 1
        case .decrement: count -= 1
        case .reset:     count = 0
        }
    }
}
```

**Step 3: `MVICounterView.swift`**

```swift
// MVICounterView.swift
import SwiftUI

struct MVICounterView: View {
    @StateObject private var model = MVICounterModel()

    var body: some View {
        CounterLayout(
            title: "MVI",
            subtitle: "Intent → Model → View",
            count: model.count,
            onIncrement: { model.process(.increment) },
            onDecrement: { model.process(.decrement) },
            onReset:     { model.process(.reset) }
        )
    }
}
```

**Step 4: `MVIFlow.swift`**

```swift
// MVIFlow.swift
import CombineFlow
import SwiftUI
import UIKit

final class MVIFlow: Flow {
    private weak var navigationController: UINavigationController?

    var root: Presentable {
        guard let nav = navigationController else { fatalError() }
        return nav
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? CounterStep else { return .none }
        switch step {
        case .showCounter:
            let vc = UIHostingController(rootView: MVICounterView())
            navigationController?.setViewControllers([vc], animated: false)
            return .one(flowContributor: .contribute(
                withNextPresentable: vc,
                withNextStepper: NoneStepper()
            ))
        }
    }
}
```

**Step 5: 커밋**

```bash
cd ~/LodyProjects/CombineFlow
git add Example/Sources/Features/MVI/
git commit -m "feat: add MVIFlow with unidirectional Intent→Model→View pattern"
```

---

## Tab 4: Reactor (ReactorKit 스타일 MVI 변형)

### Task 9: ReactorFlow + CounterReactor + View

Action → Mutation → State 3단계 변환. ReactorKit 없이 순수 Combine으로 구현.

**Files:**
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/Reactor/CounterReactor.swift`
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/Reactor/ReactorCounterView.swift`
- Create: `~/LodyProjects/CombineFlow/Example/Sources/Features/Reactor/ReactorFlow.swift`

**Step 1: 디렉토리 생성**

```bash
mkdir -p ~/LodyProjects/CombineFlow/Example/Sources/Features/Reactor
```

**Step 2: `CounterReactor.swift`**

```swift
// CounterReactor.swift
// ReactorKit 패턴을 순수 Combine으로 모방:
// Action → mutate() → Mutation → reduce() → State

import Combine
import Foundation

@MainActor
final class CounterReactor: ObservableObject {
    // MARK: - Action (외부 입력)
    enum Action {
        case increment
        case decrement
        case reset
    }

    // MARK: - Mutation (내부 상태 변화 단위)
    enum Mutation {
        case setCount(Int)
    }

    // MARK: - State
    struct State: Equatable {
        var count = 0
    }

    @Published private(set) var state = State()

    func action(_ action: Action) {
        let mutations = mutate(action: action)
        mutations.forEach { mutation in
            state = reduce(state: state, mutation: mutation)
        }
    }

    // Action → [Mutation] 변환 (비동기 작업 삽입 지점)
    private func mutate(action: Action) -> [Mutation] {
        switch action {
        case .increment: return [.setCount(state.count + 1)]
        case .decrement: return [.setCount(state.count - 1)]
        case .reset:     return [.setCount(0)]
        }
    }

    // (State, Mutation) → State 순수 함수
    private func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case .setCount(let value): newState.count = value
        }
        return newState
    }
}
```

**Step 3: `ReactorCounterView.swift`**

```swift
// ReactorCounterView.swift
import SwiftUI

struct ReactorCounterView: View {
    @StateObject private var reactor = CounterReactor()

    var body: some View {
        CounterLayout(
            title: "Reactor",
            subtitle: "Action → Mutation → State",
            count: reactor.state.count,
            onIncrement: { reactor.action(.increment) },
            onDecrement: { reactor.action(.decrement) },
            onReset:     { reactor.action(.reset) }
        )
    }
}
```

**Step 4: `ReactorFlow.swift`**

```swift
// ReactorFlow.swift
import CombineFlow
import SwiftUI
import UIKit

final class ReactorFlow: Flow {
    private weak var navigationController: UINavigationController?

    var root: Presentable {
        guard let nav = navigationController else { fatalError() }
        return nav
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? CounterStep else { return .none }
        switch step {
        case .showCounter:
            let vc = UIHostingController(rootView: ReactorCounterView())
            navigationController?.setViewControllers([vc], animated: false)
            return .one(flowContributor: .contribute(
                withNextPresentable: vc,
                withNextStepper: NoneStepper()
            ))
        }
    }
}
```

**Step 5: 커밋**

```bash
cd ~/LodyProjects/CombineFlow
git add Example/Sources/Features/Reactor/
git commit -m "feat: add ReactorFlow with Action→Mutation→State pattern"
```

---

## 빌드 검증

### Task 10: NoneStepper 접근 가능 여부 확인 + tuist generate + 빌드

`NoneStepper`는 CombineFlow 라이브러리 내부에서 `internal`로 선언됨. Example 앱에서 사용하려면 `public`으로 변경 필요.

**Files:**
- Modify: `~/LodyProjects/CombineFlow/CombineFlow/Sources/CombineFlow/Stepper.swift`

**Step 1: `NoneStepper` public으로 변경**

`Stepper.swift` 마지막 줄:
```swift
// 변경 전
final class NoneStepper: OneStepper {
    convenience init() { self.init(withSingleStep: NoneStep()) }
}

// 변경 후
public final class NoneStepper: OneStepper {
    public convenience init() { self.init(withSingleStep: NoneStep()) }
}
```

**Step 2: tuist generate**

```bash
cd ~/LodyProjects/CombineFlow
tuist generate --no-open
```

**Step 3: 빌드**

```bash
xcodebuild build \
  -workspace CombineFlow.xcworkspace \
  -scheme CombineFlowExample \
  -destination "platform=iOS Simulator,name=iPhone 15,OS=latest" \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | tail -20
```

Expected: `** BUILD SUCCEEDED **`

에러 발생 시 에러 메시지를 보고하고 수정 후 재빌드.

**Step 4: 커밋**

```bash
cd ~/LodyProjects/CombineFlow
git add CombineFlow/Sources/CombineFlow/Stepper.swift Example/Sources/
git commit -m "fix: make NoneStepper public; finalize example app"
```
