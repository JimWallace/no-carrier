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

    /// What it does, in ten words or fewer, in the terminal voice. Built
    /// from its kind and numbers, so it cannot disagree with the rules. A
    /// card that says THIS SLOT is played on a slot (`1 3`); any other is
    /// played on its own (`1`).
    public var rules: String {
        let amount = amount ?? 0
        let penalty = penalty ?? 0
        return switch kind {
        case .symbol: "SHOWS \(symbol ?? "?")."
        case .dial: "SHOWS \(symbol ?? "?"). TURN IT TO ANY SYMBOL IN PLACE."
        case .probe: "REVEALS THIS SLOT OF THE CODE."
        case .sniff: "IS THIS SLOT'S SYMBOL ANYWHERE IN THE CODE?"
        case .count: "HOW MANY OF THIS SLOT'S SYMBOL ARE IN THE CODE?"
        case .lock: "SCRAMBLE CANNOT MOVE THIS SLOT'S CARD."
        case .debug: amount > 0 ? "NEXT GUESS MARKS EACH SLOT. ALARM +\(amount)." : "NEXT GUESS MARKS EACH SLOT."
        case .spoof: "NEXT GUESS COSTS \(amount)% ALARM."
        case .shift: "MOVES YOUR WHOLE BOARD ONE SLOT RIGHT."
        case .overclock: penalty > 0 ? "+\(amount) ENERGY NOW, -\(penalty) NEXT TURN." : "+\(amount) ENERGY NOW."
        }
    }

    /// The most words `rules` may use: a card must read at a glance.
    public static let maxRuleWords = 10
}
