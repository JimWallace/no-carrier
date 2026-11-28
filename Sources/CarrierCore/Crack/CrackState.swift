/// One crack in progress. A value: the engine returns a new one per action.
public struct CrackState: Codable, Sendable, Equatable {
    public let seed: UInt64
    /// The server this crack is against.
    public let server: CrackServer
    /// The hidden code. A frontend must not show it before the end.
    public internal(set) var code: [String]
    /// One entry per slot; nil is an empty slot.
    public internal(set) var board: [CrackSlot?]
    /// What probes have revealed: the code's symbol per slot, nil while
    /// unknown.
    public internal(set) var revealed: [String?]
    public internal(set) var hand: [CardInstance] = []
    public internal(set) var drawPile: [CardInstance]
    public internal(set) var discardPile: [CardInstance] = []
    public internal(set) var energy = 0
    public internal(set) var alarm = 0
    public internal(set) var turn = 0
    public internal(set) var guesses: [CrackGuess] = []
    public internal(set) var outcome: CrackOutcome?
    /// For each ROTATE so far, how many guesses had been made when it
    /// happened. A solver needs it to read old feedback against the code
    /// as it was.
    public internal(set) var rotations: [Int] = []
    /// What SNIFF and COUNT have learned, in order.
    public internal(set) var facts: [CrackFact] = []
    /// Slots LOCK has pinned against SCRAMBLE.
    public internal(set) var locked: [Bool]
    /// DEBUG: the next guess is answered per slot, for this much more alarm.
    public internal(set) var debugAlarm: Int?
    /// SPOOF: the next guess costs this percent of its alarm.
    public internal(set) var spoofPercent: Int?
    /// OVERCLOCK: the energy the next turn loses.
    public internal(set) var energyDebt = 0
    var rng: Xoshiro256StarStar

    public var isOver: Bool { outcome != nil }

    init(
        seed: UInt64, server: CrackServer, code: [String], drawPile: [CardInstance], rng: Xoshiro256StarStar
    ) {
        let slots = server.codeLength
        self.seed = seed
        self.server = server
        self.code = code
        self.board = Array(repeating: nil, count: slots)
        self.revealed = Array(repeating: nil, count: slots)
        self.locked = Array(repeating: false, count: slots)
        self.drawPile = drawPile
        self.rng = rng
    }
}
