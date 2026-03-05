// FlowContributor.swift
// CombineFlow

#if canImport(UIKit)

public enum FlowContributor {
    case contribute(withNextPresentable: Presentable,
                    withNextStepper: Stepper,
                    allowStepWhenNotPresented: Bool = false,
                    allowStepWhenDismissed: Bool = false)
    case forwardToCurrentFlow(withStep: Step)
    case forwardToParentFlow(withStep: Step)

    public static func contribute(withNext nextPresentableAndStepper: Presentable & Stepper) -> FlowContributor {
        .contribute(
            withNextPresentable: nextPresentableAndStepper,
            withNextStepper: nextPresentableAndStepper
        )
    }
}

public enum FlowContributors {
    case multiple(flowContributors: [FlowContributor])
    case one(flowContributor: FlowContributor)
    case end(forwardToParentFlowWithStep: Step)
    case none
}

#endif
