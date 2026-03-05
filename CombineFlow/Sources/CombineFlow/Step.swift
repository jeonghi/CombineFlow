// Step.swift
// CombineFlow

/// A Step describes a possible state of navigation inside a Flow
public protocol Step {}

struct NoneStep: Step, Equatable {}

/// Standard CombineFlow Steps
///
/// - home: can be used to express a Flow first step
public enum CombineFlowStep: Step {
    /// can be used to express a Flow first step
    case home
}
