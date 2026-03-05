import CombineFlow

enum LoginStep: Step {
    case showLogin
    case loginCompleted(token: String)
}
