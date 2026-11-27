/// What a line typed at the fight prompt means.
enum ParsedCommand: Equatable {
    case play(handIndex: Int)
    case endTurn
    case logout
    case help
    case quit
    case empty
    case notInHand(String)
    case unknown(String)
}
