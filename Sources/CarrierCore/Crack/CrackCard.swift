/// A program in the crack prototype.
public struct CrackCard: Codable, Sendable, Equatable {
    public let id: String
    public let kind: CrackCardKind
    /// The symbol a symbol or dial card shows when it is played. Other kinds
    /// have none.
    public let symbol: String?
    /// What playing it costs. Nil: `costs.place` for a symbol or dial card,
    /// `costs.probe` for a probe. Every other kind names its own.
    public let cost: Int?
    /// The kind's number: OVERCLOCK's extra energy, SPOOF's alarm percent,
    /// DEBUG's extra alarm.
    public let amount: Int?
    /// OVERCLOCK only: the energy the next turn loses.
    public let penalty: Int?

    public init(
        id: String, kind: CrackCardKind = .symbol, symbol: String?, cost: Int? = nil, amount: Int? = nil,
        penalty: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.symbol = symbol
        self.cost = cost
        self.amount = amount
        self.penalty = penalty
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, symbol, cost, amount, penalty
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decodeIfPresent(CrackCardKind.self, forKey: .kind) ?? .symbol
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        cost = try container.decodeIfPresent(Int.self, forKey: .cost)
        amount = try container.decodeIfPresent(Int.self, forKey: .amount)
        penalty = try container.decodeIfPresent(Int.self, forKey: .penalty)
    }

    /// What the hand shows: `A`, `DIAL-A`, `PROBE`, `SNIFF`.
    public var label: String {
        switch kind {
        case .symbol: symbol ?? id
        case .dial: "DIAL-" + (symbol ?? "?")
        default: kind.rawValue.uppercased()
        }
    }

    /// What it does, in the terminal voice. Built from its kind and numbers,
    /// so it cannot disagree with the rules.
    public var rules: String {
        switch kind {
        case .symbol: "SHOWS \(symbol ?? "?") ON A SLOT."
        case .dial: "SHOWS \(symbol ?? "?") ON A SLOT. TURN IT TO ANOTHER SYMBOL WHERE IT STANDS."
        case .probe: "SHOWS WHAT A SLOT OF THE CODE REALLY IS."
        case .sniff: "PLAY ON A FULL SLOT: IS ITS SYMBOL IN THE CODE AT ALL?"
        case .count: "PLAY ON A FULL SLOT: HOW MANY OF ITS SYMBOL ARE IN THE CODE?"
        case .lock: "PLAY ON A FULL SLOT: SCRAMBLE CANNOT MOVE IT UNTIL REPLACED."
        case .debug: "NEXT GUESS MARKS EACH SLOT, ALARM +\(amount ?? 0)."
        case .spoof: "NEXT GUESS COSTS \(amount ?? 100)% ALARM."
        case .shift: "MOVES YOUR WHOLE BOARD ONE SLOT RIGHT."
        case .overclock:
            (penalty ?? 0) > 0
                ? "ENERGY +\(amount ?? 0) NOW, -\(penalty ?? 0) NEXT TURN." : "ENERGY +\(amount ?? 0) NOW."
        }
    }
}
