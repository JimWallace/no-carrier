/// One crack in progress. A value: the engine returns a new one per action.
public struct CrackState: Codable, Sendable, Equatable {
    public let seed: UInt64
    /// The hidden code. A frontend must not show it before the end.
    public let code: [String]
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
    var rng: Xoshiro256StarStar

    public var isOver: Bool { outcome != nil }

    init(seed: UInt64, code: [String], slots: Int, drawPile: [CardInstance], rng: Xoshiro256StarStar) {
        self.seed = seed
        self.code = code
        self.board = Array(repeating: nil, count: slots)
        self.revealed = Array(repeating: nil, count: slots)
        self.drawPile = drawPile
        self.rng = rng
    }
}
