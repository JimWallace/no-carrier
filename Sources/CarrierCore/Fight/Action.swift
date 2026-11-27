/// Everything a player (or a bot, or a replay) can do. The frontend sends
/// these and nothing else.
public enum Action: Codable, Sendable, Equatable {
    /// Plays the card at this position in the hand (0-based).
    case play(handIndex: Int)
    /// `END`: discard the hand and let the ICE act.
    case endTurn
    /// `LOGOUT`: leave the fight; the node is unchanged and Trace goes up.
    case logout
}
