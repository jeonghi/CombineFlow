# AuthenticationService Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `AuthenticationService` (reactive observer pattern) with logout + token expiration, and a Settings tab that triggers these events, redirecting the app to SplashFlow.

**Architecture:** `AuthenticationService.shared` holds a `PassthroughSubject<AuthEvent, Never>` stream. `AppFlow` subscribes to this stream in `init()` via its own `AppStepper`, and emits `AppStep.splash` on logout/tokenExpired. A new Settings tab (5th tab) provides logout and expiration simulation buttons.

**Tech Stack:** Swift 6.0, Combine, CombineFlow (local framework), SwiftUI, UIKit (UITabBarController)

---

## Context

### Project structure
```
/Users/jeonghi/LodyProjects/CombineFlow/
├── CombineFlow/Sources/CombineFlow/   ← framework (do not modify)
└── Example/Sources/
    ├── App/
    │   ├── AppDelegate.swift
    │   ├── SceneDelegate.swift
    │   ├── AppStep.swift
    │   └── AppFlow.swift
    ├── Services/                      ← 신규 디렉토리
    └── Features/
        ├── Splash/   Login/   Main/
        ├── MVVM/  TCA/  MVI/  Reactor/
        └── Settings/                  ← 신규 디렉토리
```

### Key CombineFlow types
- `PublishRelay<Step>`: `accept(_:)` 메서드로 Step을 방출하는 Combine Publisher
- `Stepper` protocol: `steps: PublishRelay<Step>`, `initialStep: Step`
- `OneStepper(withSingleStep:)`: 단일 initialStep을 가진 Stepper
- `FlowContributors.none`: navigate 함수에서 아무것도 안 할 때 반환

### Current AppFlow (전체 교체 대상)
```swift
// Example/Sources/App/AppFlow.swift
final class AppFlow: Flow {
    private let navigationController = UINavigationController()
    var root: Presentable { navigationController }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? AppStep else { return .none }
        switch step {
        case .splash: return navigateToSplash()
        case .login: return navigateToLogin()
        case .loginCompleted, .main: return navigateToMain()
        }
    }
    // ... private methods
}
```

### Current SceneDelegate (수정 대상)
```swift
coordinator.coordinate(
    flow: appFlow,
    with: OneStepper(withSingleStep: AppStep.splash)  // ← AppStepper로 교체
)
```

### Current LoginFlow (수정 대상)
```swift
case .loginCompleted(let token):
    return .end(forwardToParentFlowWithStep: AppStep.loginCompleted(token: token))
// ← login(token:) 호출 추가 필요
```

---

## Task 1: AuthenticationService 생성

**Files:**
- Create: `Example/Sources/Services/AuthenticationService.swift`

**Step 1: 파일 생성**

```swift
// Example/Sources/Services/AuthenticationService.swift
import Combine
import Foundation

final class AuthenticationService: @unchecked Sendable {
    static let shared = AuthenticationService()
    private init() {}

    enum AuthEvent: Equatable {
        case loggedIn(token: String)
        case loggedOut
        case tokenExpired
    }

    private(set) var token: String?
    let authEvents = PassthroughSubject<AuthEvent, Never>()

    private var expirationTask: Task<Void, Never>?

    func login(token: String) {
        self.token = token
        authEvents.send(.loggedIn(token: token))
    }

    func logout() {
        expirationTask?.cancel()
        expirationTask = nil
        token = nil
        authEvents.send(.loggedOut)
    }

    func expireToken() {
        expirationTask?.cancel()
        expirationTask = nil
        token = nil
        authEvents.send(.tokenExpired)
    }

    func startExpirationTimer(after seconds: TimeInterval) {
        expirationTask?.cancel()
        expirationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.expireToken()
        }
    }
}
```

**Step 2: 빌드 확인**

```bash
cd /Users/jeonghi/LodyProjects/CombineFlow
tuist generate
```
Xcode에서 `Cmd+B` → 빌드 성공 확인.

**Step 3: 커밋**

```bash
git add Example/Sources/Services/AuthenticationService.swift
git commit -m "feat: add AuthenticationService with reactive observer pattern"
```

---

## Task 2: AppStepper 생성 + AppFlow 통합

**Files:**
- Create: `Example/Sources/App/AppStepper.swift`
- Modify: `Example/Sources/App/AppFlow.swift`
- Modify: `Example/Sources/App/SceneDelegate.swift`

**Step 1: AppStepper 파일 생성**

```swift
// Example/Sources/App/AppStepper.swift
import CombineFlow

final class AppStepper: Stepper {
    let steps = PublishRelay<Step>()
    var initialStep: Step { AppStep.splash }
}
```

**Step 2: AppFlow 전면 교체**

`Example/Sources/App/AppFlow.swift`를 아래 내용으로 교체:

```swift
import CombineFlow
import Combine
import UIKit

final class AppFlow: Flow {
    private let navigationController = UINavigationController()
    let stepper = AppStepper()  // SceneDelegate에서 접근하므로 internal
    private var cancellables = Set<AnyCancellable>()

    var root: Presentable { navigationController }

    init() {
        AuthenticationService.shared.authEvents
            .filter { $0 == .loggedOut || $0 == .tokenExpired }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.stepper.steps.accept(AppStep.splash)
            }
            .store(in: &cancellables)
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? AppStep else { return .none }
        switch step {
        case .splash:
            return navigateToSplash()
        case .login:
            return navigateToLogin()
        case .loginCompleted, .main:
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

**Step 3: SceneDelegate 수정**

`coordinator.coordinate(...)` 호출 부분을 `OneStepper` → `appFlow.stepper`로 교체:

```swift
// 변경 전
coordinator.coordinate(
    flow: appFlow,
    with: OneStepper(withSingleStep: AppStep.splash)
)

// 변경 후
coordinator.coordinate(
    flow: appFlow,
    with: appFlow.stepper
)
```

**Step 4: 빌드 확인**

Xcode `Cmd+B` → 빌드 성공. 앱 실행 시 Splash → Login 흐름 동작 확인.

**Step 5: 커밋**

```bash
git add Example/Sources/App/AppStepper.swift \
        Example/Sources/App/AppFlow.swift \
        Example/Sources/App/SceneDelegate.swift
git commit -m "feat: integrate AppStepper and authEvents subscription into AppFlow"
```

---

## Task 3: LoginFlow에서 AuthenticationService.login() 호출

**Files:**
- Modify: `Example/Sources/Features/Login/LoginFlow.swift`

**Step 1: loginCompleted case에 login(token:) 추가**

`LoginFlow.swift` 내 `navigate(to:)` 함수의 `.loginCompleted(let token):` case를:

```swift
// 변경 전
case .loginCompleted(let token):
    return .end(forwardToParentFlowWithStep: AppStep.loginCompleted(token: token))

// 변경 후
case .loginCompleted(let token):
    AuthenticationService.shared.login(token: token)
    return .end(forwardToParentFlowWithStep: AppStep.loginCompleted(token: token))
```

**Step 2: 빌드 및 동작 확인**

Xcode `Cmd+B`. 앱 실행 → 로그인 버튼 탭 → Main 탭바 진입 확인.

**Step 3: 커밋**

```bash
git add Example/Sources/Features/Login/LoginFlow.swift
git commit -m "feat: call AuthenticationService.login on token creation"
```

---

## Task 4: Settings Feature 생성

**Files:**
- Create: `Example/Sources/Features/Settings/SettingsStep.swift`
- Create: `Example/Sources/Features/Settings/SettingsFlow.swift`
- Create: `Example/Sources/Features/Settings/SettingsView.swift`

**Step 1: SettingsStep 생성**

```swift
// Example/Sources/Features/Settings/SettingsStep.swift
import CombineFlow

enum SettingsStep: Step {
    case showSettings
}
```

**Step 2: SettingsView 생성**

```swift
// Example/Sources/Features/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @State private var tokenDisplay: String = ""
    @State private var timerActive = false

    var body: some View {
        NavigationStack {
            List {
                Section("계정") {
                    tokenRow
                    logoutButton
                }
                Section("개발자 도구") {
                    expireButton
                    timerToggle
                }
            }
            .navigationTitle("Settings")
            .onAppear { refreshToken() }
        }
    }

    private var tokenRow: some View {
        HStack {
            Text("토큰")
            Spacer()
            Text(tokenDisplay)
                .foregroundStyle(.secondary)
                .font(.caption.monospaced())
        }
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            AuthenticationService.shared.logout()
        } label: {
            Text("로그아웃")
        }
    }

    private var expireButton: some View {
        Button("토큰 만료 시뮬레이션") {
            AuthenticationService.shared.expireToken()
        }
        .foregroundStyle(.orange)
    }

    private var timerToggle: some View {
        Toggle("30초 후 자동 만료", isOn: $timerActive)
            .onChange(of: timerActive) { _, active in
                if active {
                    AuthenticationService.shared.startExpirationTimer(after: 30)
                }
            }
    }

    private func refreshToken() {
        if let t = AuthenticationService.shared.token {
            tokenDisplay = String(t.prefix(8)) + "..."
        } else {
            tokenDisplay = "없음"
        }
    }
}
```

**Step 3: SettingsFlow 생성**

```swift
// Example/Sources/Features/Settings/SettingsFlow.swift
import CombineFlow
import SwiftUI
import UIKit

final class SettingsFlow: Flow {
    private weak var navigationController: UINavigationController?

    var root: Presentable {
        guard let nav = navigationController else { fatalError() }
        return nav
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? SettingsStep else { return .none }
        switch step {
        case .showSettings:
            let vc = UIHostingController(rootView: SettingsView())
            navigationController?.setViewControllers([vc], animated: false)
            return .one(flowContributor: .contribute(
                withNextPresentable: vc,
                withNextStepper: NoneStepper()
            ))
        }
    }
}
```

**Step 4: 빌드 확인**

Xcode `Cmd+B` → Settings 관련 파일 컴파일 성공 확인.

**Step 5: 커밋**

```bash
git add Example/Sources/Features/Settings/
git commit -m "feat: add Settings feature (SettingsStep, SettingsFlow, SettingsView)"
```

---

## Task 5: MainFlow에 Settings 탭 추가

**Files:**
- Modify: `Example/Sources/Features/Main/MainFlow.swift`

**Step 1: MainFlow 전면 교체**

`Example/Sources/Features/Main/MainFlow.swift`를 아래 내용으로 교체:

```swift
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
```

**Step 2: 빌드 및 최종 동작 확인**

Xcode `Cmd+B`. 앱 실행:
1. Splash 2초 → Login 화면
2. 로그인 버튼 탭 → MainTabBar (탭 5개)
3. Settings 탭 진입 → 토큰 앞 8자리 + 버튼 확인
4. 로그아웃 버튼 탭 → Splash로 리다이렉트 확인
5. 다시 로그인 → Settings → 토큰 만료 시뮬레이션 → Splash 리다이렉트 확인

**Step 3: 최종 커밋**

```bash
git add Example/Sources/Features/Main/MainFlow.swift
git commit -m "feat: add Settings tab to MainFlow with logout and token expiry"
```
