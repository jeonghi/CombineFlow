import CombineFlow

/// App-level Stepper. Owned by AppFlow and used to redirect the entire
/// navigation stack (e.g., back to Splash on logout or token expiry).
final class AppStepper: Stepper {
    let steps = PublishRelay<Step>()
    var initialStep: Step { AppStep.splash }
}
