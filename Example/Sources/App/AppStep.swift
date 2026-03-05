import CombineFlow

enum AppStep: Step {
    case splash
    case login
    case loginCompleted(token: String)
    case main
}
