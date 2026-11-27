/// How a fight ended.
public enum FightOutcome: String, Codable, Sendable, Equatable {
    /// Every layer breached: the node is the player's.
    case captured
    /// LOGOUT: the node is unchanged, and Trace went up.
    case loggedOut
    /// Integrity reached 0: the run is over (kickoff §10, question 2).
    case flatlined
    /// Trace reached its maximum: NO CARRIER.
    case traced
}
