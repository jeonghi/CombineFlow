import CombineFlow

final class AppStepper: Stepper {
    let steps = PublishRelay<Step>()
    var initialStep: Step { AppStep.splash }
}
