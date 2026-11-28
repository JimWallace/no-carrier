/// The code-cracking prototype (`crack.json`, addendum 03): the symbols, the
/// code, the rig and the starter deck. Every number the crack rules read is
/// here; nothing in Swift repeats one.
public struct CrackContent: Codable, Sendable, Equatable {
    /// The symbols a code is made of, in the order the screen lists them.
    public var symbols: [String]
    /// How many slots the code, and the board, has.
    public var codeLength: Int
    /// The most times one symbol may appear in a code.
    public var maxRepeats: Int
    /// The hand is drawn back up to this many cards at the start of a turn.
    public var handSize: Int
    /// Energy each turn.
    public var energy: Int
    public var costs: CrackCosts
    public var alarm: CrackAlarm
    public var cards: [CrackCard]
    public var starterDeck: [String]

    public func card(_ id: String) -> CrackCard? {
        cards.first { $0.id == id }
    }
}

/// What each board action costs in energy.
public struct CrackCosts: Codable, Sendable, Equatable {
    /// A card from the hand onto a slot.
    public var place: Int
    /// Two slots trade cards.
    public var swap: Int
    /// A card from the hand onto the discard pile.
    public var drop: Int
}

/// The alarm: each guess raises it, and at `max` the line drops.
public struct CrackAlarm: Codable, Sendable, Equatable {
    public var max: Int
    public var perGuess: Int
}
