# AuthenticationService 설계 — Reactive Observer Pattern

**Date:** 2026-03-05

## Goal

CombineFlowExample 앱에 인증 상태 관리 전역 객체(`AuthenticationService`)를 추가하고,
로그아웃 및 토큰 만료 시 `AppFlow`가 SplashFlow로 리다이렉트하는 구조를 구현한다.

---

## 패턴 선택: Reactive Observer

- **Pub-Sub (NotificationCenter)**: Publisher ↔ Subscriber 사이에 Broker가 존재. 결합도 낮지만 타입 안전성 없음. **선택 안 함.**
- **Imperative Observer (protocol + weak refs)**: 전통적 OOP 옵저버. Combine 코드베이스에 이질적.
- **Reactive Observer (Combine Subject + .sink)**: Subject가 Observer를 직접 스트림으로 연결. Combine 환경에 자연스럽고 타입 안전. **선택.**

---

## 컴포넌트

### AuthenticationService

```
Services/AuthenticationService.swift
```

```swift
final class AuthenticationService: @unchecked Sendable {
    static let shared = AuthenticationService()

    private(set) var token: String? = nil

    let authEvents = PassthroughSubject<AuthEvent, Never>()

    enum AuthEvent {
        case loggedIn(token: String)
        case loggedOut
        case tokenExpired
    }

    func login(token: String)
    func logout()
    func expireToken()                              // 수동 시뮬레이션 버튼용
    func startExpirationTimer(after: TimeInterval) // 타이머 기반 자동 만료
}
```

### AppStepper

`AppFlow` 자신이 Step을 방출할 수 있도록 별도 Stepper 추가.

```swift
final class AppStepper: Stepper {
    let steps = PublishRelay<Step>()
    var initialStep: Step { AppStep.splash }
}
```

### AppFlow 통합

```swift
final class AppFlow: Flow {
    private let stepper = AppStepper()
    private var cancellables = Set<AnyCancellable>()

    init() {
        AuthenticationService.shared.authEvents
            .filter { $0 == .loggedOut || $0 == .tokenExpired }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.stepper.steps.accept(AppStep.splash)
            }
            .store(in: &cancellables)
    }
}
```

- `loggedOut` / `tokenExpired` 수신 → `AppStep.splash` emit
- `AppStep.splash` → `SplashFlow` 다시 시작, MainFlow 자동 해제

### Settings 탭 (5번째 탭)

```
Features/Settings/
├── SettingsStep.swift      — case showSettings
├── SettingsFlow.swift
└── SettingsView.swift
```

**SettingsView UI:**
- 현재 토큰 표시 (UUID 앞 8자리)
- 로그아웃 버튼 → `AuthenticationService.shared.logout()`
- 토큰 만료 시뮬레이션 버튼 → `AuthenticationService.shared.expireToken()`
- 타이머 토글 (30초 자동 만료) → `AuthenticationService.shared.startExpirationTimer(after: 30)`

### MainFlow 변경

탭 5개로 확장:
```
Tab1: MVVM    Tab2: TCA    Tab3: MVI    Tab4: Reactor    Tab5: Settings
```

---

## 데이터 흐름

```
[Settings 로그아웃 버튼]
        │
        ▼
AuthenticationService.shared.logout()
        │  authEvents.send(.loggedOut)
        ▼
AppFlow.cancellables sink
        │  stepper.steps.accept(AppStep.splash)
        ▼
AppFlow.navigate(to: .splash)
        │
        ▼
SplashFlow 시작, MainFlow 해제
```

---

## 디렉토리 구조 변경사항

```
Example/Sources/
├── App/
│   ├── AppStepper.swift        ← 신규
│   └── AppFlow.swift           ← AppStepper 주입, authEvents 구독 추가
├── Services/
│   └── AuthenticationService.swift  ← 신규
└── Features/
    ├── Login/
    │   └── LoginFlow.swift     ← login(token:) 호출 추가
    ├── Main/
    │   └── MainFlow.swift      ← Settings 탭 추가
    └── Settings/               ← 신규
        ├── SettingsStep.swift
        ├── SettingsFlow.swift
        └── SettingsView.swift
```
