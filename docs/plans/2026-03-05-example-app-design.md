# CombineFlow Example App — 확장 설계

**Date:** 2026-03-05

## Goal

CombineFlowExample 앱에 Splash → Login → MainTabBar(4탭) 구조를 추가하고,
각 탭에서 동일한 카운터 주제를 MVVM / TCA / MVI / Reactor 패턴으로 구현해 아키텍처를 비교한다.

## Flow 구조

```
AppFlow
├── SplashFlow        → 2초 후 자동 전환
├── LoginFlow         → 버튼 탭 → UUID 토큰 생성 → MainFlow
└── MainFlow (TabBarController)
    ├── Tab1: MVVMFlow     — 카운터 (MVVM + Combine)
    ├── Tab2: TCAFlow      — 카운터 (TCA / ComposableArchitecture)
    ├── Tab3: MVIFlow      — 카운터 (MVI, 단방향 Intent→Model→View)
    └── Tab4: ReactorFlow  — 카운터 (ReactorKit 스타일: action→mutation→state)
```

## 화면 상세

| 화면 | UI | 핵심 |
|------|-----|------|
| Splash | SwiftUI | 앱 로고 텍스트 + 2초 딜레이 후 LoginStep 방출 |
| Login | SwiftUI | "로그인" 버튼 → UUID 토큰 생성 → token을 Step에 담아 Main 이동 |
| Tab1 MVVM | SwiftUI | CounterViewModel: @Published count, increment/decrement/reset |
| Tab2 TCA | SwiftUI | CounterFeature: Reducer, Action enum, store |
| Tab3 MVI | SwiftUI | MVICounterModel(ObservableObject) + Intent enum, 단방향 |
| Tab4 Reactor | SwiftUI | CounterReactor: Action→Mutation→State 3단계 변환 |

## 의존성

- `CombineFlow` (로컬 프레임워크)
- `ComposableArchitecture` (1.10.0+, TCA 탭 전용)

## 디렉토리 구조

```
Example/Sources/
├── App/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── AppStep.swift
│   └── AppFlow.swift
└── Features/
    ├── Splash/
    │   ├── SplashView.swift
    │   └── SplashFlow.swift
    ├── Login/
    │   ├── LoginView.swift
    │   └── LoginFlow.swift
    ├── Main/
    │   └── MainFlow.swift
    ├── MVVM/
    │   ├── MVVMCounterViewModel.swift
    │   ├── MVVMCounterView.swift
    │   └── MVVMFlow.swift
    ├── TCA/
    │   ├── TCACounterFeature.swift
    │   ├── TCACounterView.swift
    │   └── TCAFlow.swift
    ├── MVI/
    │   ├── MVICounterModel.swift
    │   ├── MVICounterView.swift
    │   └── MVIFlow.swift
    └── Reactor/
        ├── CounterReactor.swift
        ├── ReactorCounterView.swift
        └── ReactorFlow.swift
```

## 기존 파일 처리

- `Features/Counter/`, `Features/Detail/` 폴더 전면 삭제
- `App/AppStep.swift`, `App/AppFlow.swift` 전면 교체
