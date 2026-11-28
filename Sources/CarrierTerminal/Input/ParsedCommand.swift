/// What a line typed at the fight prompt means.
package enum ParsedCommand: Equatable {
    case play(handIndex: Int)
    case endTurn
    case logout
    case help
    /// `INFO N` or `? N`: the full rules of the card at that hand position.
    case info(handIndex: Int)
    case quit
    case empty
    case notInHand(String)
    case unknown(String)
}
