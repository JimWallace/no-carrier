/// A crack run (`crack.json`, `run`): servers in a row with a reward after
/// each crack but the last.
public struct CrackRunContent: Codable, Sendable, Equatable {
    /// Server ids, in the order the run meets them.
    public var servers: [String]
    /// How many cards a reward offers.
    public var rewardChoices: Int
    /// The cards a reward draws from.
    public var rewardPool: [String]
    /// The most cards the deck may hold. At the limit, a reward can remove
    /// a card or be skipped, but not add one.
    public var deckLimit: Int
}
