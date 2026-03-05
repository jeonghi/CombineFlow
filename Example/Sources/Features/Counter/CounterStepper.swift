import CombineFlow

final class CounterStepper: Stepper {
    let steps = PublishRelay<Step>()

    func counterDone(count: Int) {
        steps.accept(CounterStep.counterDone(count: count))
    }
}
