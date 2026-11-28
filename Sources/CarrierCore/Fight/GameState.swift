/// The state the reducer works on. In M2 it is one fight; M3 adds the
/// network around it.
public struct GameState: Codable, Sendable, Equatable {
    /// The seed everything in this game was derived from.
    public var seed: UInt64
    public var fight: FightState
    /// The rules the fight runs under (addendum 02, §1).
    public var rules: RuleSet

    public init(seed: UInt64, fight: FightState, rules: RuleSet) {
        self.seed = seed
        self.fight = fight
        self.rules = rules
    }
}
