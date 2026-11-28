/// What `act` did with an input.
package enum ActStatus: String, Sendable {
    /// The engine took an action.
    case ok
    /// A question (INFO, DECK, HELP) or a step of a two-step choice: no
    /// rule state changed.
    case info
    /// Refused. Nothing changed, the log included.
    case rejected
}

/// The result of `act`, before the view is added.
package struct ActOutcome: Sendable {
    package let status: ActStatus
    /// The log lines the input added (for a rejection: the reason).
    package let lines: [String]
}
