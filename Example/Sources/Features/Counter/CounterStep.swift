import CombineFlow

enum CounterStep: Step {
    case showCounter
    case counterDone(count: Int)
}
