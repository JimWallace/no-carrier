/// The code-cracking prototype (`crack.json`, addendum 03): the symbols,
/// the rig, the starter deck and the servers. Every number the crack rules
/// read is here; nothing in Swift repeats one.
public struct CrackContent: Codable, Sendable, Equatable {
    /// Every symbol a card or a dial can show, in the order the dial turns.
    /// A server's code uses some or all of them.
    public var symbols: [String]
    /// The hand is drawn back up to this many cards at the start of a turn.
    public var handSize: Int
    /// Energy each turn.
    public var energy: Int
    public var costs: CrackCosts
    public var alarm: CrackAlarm
    public var cards: [CrackCard]
    public var starterDeck: [String]
    /// The kinds of server a crack can be against. The first is the
    /// default.
    public var servers: [CrackServer]
    /// A run: servers in a row, a reward after each crack.
    public var run: CrackRunContent
    /// The game words card text shows in bold, with their explanations.
    public var keywords: [CrackKeyword]

    public func card(_ id: String) -> CrackCard? {
        cards.first { $0.id == id }
    }

    public func server(_ id: String) -> CrackServer? {
        servers.first { $0.id == id }
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
    /// A dial turned one step along `symbols` (the list wraps). Turning
    /// costs this for each step, by the shorter way round.
    public var turn: Int
    /// A probe played on a slot.
    public var probe: Int
}

/// The alarm: at `max` the line drops. Each server sets what a guess adds.
public struct CrackAlarm: Codable, Sendable, Equatable {
    public var max: Int
    /// What a HOLD (a turn ended without a guess) adds.
    public var hold: Int
}
