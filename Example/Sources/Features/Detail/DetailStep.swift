import CombineFlow

enum DetailStep: Step {
    case showDetail(count: Int)
    case dismiss
}
