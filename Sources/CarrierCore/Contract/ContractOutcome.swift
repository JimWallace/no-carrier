/// How a contract ended.
public enum ContractOutcome: String, Codable, Sendable, Equatable {
    /// ROOT captured.
    case won
    /// Integrity reached 0 in a fight.
    case flatlined
    /// Trace reached its maximum: NO CARRIER.
    case traced
    /// The sysop took the ENTRY node.
    case entryLost
    /// JACK OUT before the objective was complete.
    case jackedOut
}

extension ContractOutcome {
    /// The line that ends the contract, for every frontend. A win names
    /// what the objective was.
    public func title(win: ObjectiveWin) -> String {
        switch self {
        case .won: win == .exfiltrate ? "FILE DELIVERED. CONTRACT COMPLETE." : "ROOT ACCESS. CONTRACT COMPLETE."
        case .flatlined: "INTEGRITY 0. RUN OVER."
        case .traced: "NO CARRIER"
        case .entryLost: "ENTRY LOST. CONTRACT FAILED."
        case .jackedOut: "JACKED OUT. OBJECTIVE NOT MET."
        }
    }
}
