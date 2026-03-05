# CombineFlow

CombineFlow is a UIKit navigation framework built on top of the Coordinator pattern with Combine.

_KR: CombineFlow는 Coordinator 패턴을 Combine 기반으로 구현한 UIKit 네비게이션 프레임워크입니다._

It keeps the Flow/Step mental model from RxFlow, but updates the implementation for modern Swift and Combine-first apps.

_KR: RxFlow의 Flow/Step 사고방식은 유지하면서, 구현은 Swift + Combine 기준으로 정리했습니다._

## What This Repo Contains

- `CombineFlow/`: framework source and tests
- `Example/`: runnable iOS example app
- `docs/plans/`: design and implementation notes

_KR: 이 저장소에는 프레임워크 본체, 예제 앱, 설계 문서가 함께 들어 있습니다._

## Why CombineFlow

UIKit navigation usually becomes hard to maintain when projects grow.

- View controllers start owning both UI and navigation logic.
- Transition rules spread across screens.
- Tab, modal, and deep-link flows are hard to reason about globally.

CombineFlow separates these concerns clearly:

- `Step` represents navigation intent.
- `Flow` maps each step to actual navigation.
- `FlowCoordinator` connects parent/child flows and propagates steps.

_KR: 화면 이동 정책을 Flow로 모으고, Step으로 이동 의도를 통일하며, Coordinator가 연결을 담당합니다._

## Core Concepts

### `Step`

A value that describes a navigation state or intent.

_KR: 네비게이션 상태/의도를 나타내는 값입니다._

### `Stepper`

An object that emits steps through `PublishRelay<Step>`.

_KR: `PublishRelay<Step>`를 통해 Step을 방출하는 주체입니다._

### `Flow`

Defines how to handle incoming steps in `navigate(to:)`.

_KR: `navigate(to:)`에서 Step을 실제 전환으로 바꾸는 규칙을 정의합니다._

### `Presentable`

A displayable abstraction (`UIViewController`, `Flow`, and `UIWindow` are supported).

_KR: 표시 가능한 대상을 추상화한 프로토콜입니다._

### `FlowContributor` / `FlowContributors`

Describes what the coordinator should listen to next.

_KR: 다음 단계에서 Coordinator가 연결할 대상을 정의합니다._

### `FlowCoordinator`

Coordinates flows, forwards steps, and applies optional step adaptation.

_KR: Flow 연결, Step 전달, adaptation 처리를 담당합니다._

## Getting Started

This repository uses Tuist.

```bash
tuist install
tuist generate
open CombineFlow.xcworkspace
```

Build the example app:

```bash
xcodebuild build \
  -workspace CombineFlow.xcworkspace \
  -scheme CombineFlowExample \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  CODE_SIGNING_ALLOWED=NO
```

_KR: Tuist로 워크스페이스를 생성한 뒤 `CombineFlowExample` 스킴을 빌드하면 됩니다._

## Minimal Usage

### 1) Define steps

```swift
import CombineFlow

enum AppStep: Step {
    case splash
    case login
    case loginCompleted(token: String)
    case main
}
```

### 2) Define a stepper

```swift
import CombineFlow

final class AppStepper: Stepper {
    let steps = PublishRelay<Step>()
    var initialStep: Step { AppStep.splash }
}
```

### 3) Define a flow

```swift
import Combine
import CombineFlow
import UIKit

@MainActor
final class AppFlow: Flow {
    private let navigationController = UINavigationController()
    let stepper = AppStepper()
    private var cancellables = Set<AnyCancellable>()

    var root: Presentable { navigationController }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? AppStep else { return .none }

        switch step {
        case .splash:
            let splashFlow = SplashFlow(navigationController: navigationController)
            return .one(flowContributor: .contribute(
                withNextPresentable: splashFlow,
                withNextStepper: OneStepper(withSingleStep: SplashStep.start)
            ))

        case .login:
            let loginFlow = LoginFlow(navigationController: navigationController)
            return .one(flowContributor: .contribute(
                withNextPresentable: loginFlow,
                withNextStepper: OneStepper(withSingleStep: LoginStep.showLogin)
            ))

        case .loginCompleted:
            let mainFlow = MainFlow()
            Flows.use([mainFlow], when: .created) { [weak self] (roots: [UITabBarController]) in
                self?.navigationController.setViewControllers([roots[0]], animated: false)
            }
            return .one(flowContributor: .contribute(
                withNextPresentable: mainFlow,
                withNextStepper: OneStepper(withSingleStep: MainStep.showMain)
            ))

        case .main:
            return .none
        }
    }
}
```

### 4) Bootstrap in `SceneDelegate`

```swift
import CombineFlow
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
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

        coordinator.coordinate(flow: appFlow, with: appFlow.stepper)
    }
}
```

_KR: Step/Stepper/Flow를 만든 뒤 SceneDelegate에서 `coordinate`를 호출하면 기본 설정이 끝납니다._

## Step Adaptation

`adapt(step:)` runs before `navigate(to:)`.

Use it when you need to gate or rewrite steps (authentication, permissions, feature flags, etc.).

```swift
func adapt(step: Step) -> AnyPublisher<Step, Never> {
    guard let appStep = step as? AppStep else {
        return Just(step).eraseToAnyPublisher()
    }

    switch appStep {
    case .main where AuthenticationService.shared.token == nil:
        return Just(AppStep.login).eraseToAnyPublisher()
    default:
        return Just(appStep).eraseToAnyPublisher()
    }
}
```

_KR: `adapt(step:)`는 실제 화면 전환 전에 필터/분기 로직을 넣는 지점입니다._

## FlowContributors Cheatsheet

- `.none`: no action
- `.one(.contribute(...))`: connect one next presentable + stepper
- `.multiple(...)`: connect multiple contributors
- `.one(.forwardToCurrentFlow(withStep:))`: re-inject a step into current flow
- `.one(.forwardToParentFlow(withStep:))`: forward a step to parent flow
- `.end(forwardToParentFlowWithStep:)`: finish current flow and notify parent

`FlowContributor.contribute` options:

- `allowStepWhenNotPresented`
- `allowStepWhenDismissed`

_KR: 대부분의 경우 `.contribute`와 `.end` 두 가지를 중심으로 쓰게 됩니다._

## Example App

`CombineFlowExample` demonstrates:

- Splash → Login → Main flow chain
- tab-based architecture with independent navigation stacks
- five tabs (`MVVM`, `TCA`, `MVI`, `Reactor`, `Settings`)
- 2-depth navigation examples in each tab
- automatic tab bar hiding for depth 2+ screens

_KR: 예제 앱은 같은 화면 주제를 아키텍처별로 비교하는 데 초점을 둡니다._

## Migrating from RxFlow

- Replace RxSwift/RxCocoa types with Combine.
- `Stepper.steps` is `PublishRelay<Step>`.
- `adapt(step:)` returns `AnyPublisher<Step, Never>`.
- Use `willNavigate` and `didNavigate` for navigation tracing.
- If `SwiftUI.Stepper` conflicts with protocol name, use `CombineFlow.Stepper` explicitly.

_KR: 실제 마이그레이션에서는 Stepper 타입 충돌과 adaptation 반환 타입부터 맞추는 것이 가장 효과적입니다._

## Repository

- GitHub: https://github.com/jeonghi/CombineFlow.git

---

This README is based on the current API and example structure in this repository.

_KR: 이 문서는 현재 저장소의 API/예제 구조 기준으로 작성되었습니다._
