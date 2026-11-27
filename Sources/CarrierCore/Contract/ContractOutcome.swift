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
}
