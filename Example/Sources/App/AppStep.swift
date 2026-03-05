import CombineFlow

enum AppStep: Step {
    case counterRequested
    case counterCompleted(count: Int)
}
