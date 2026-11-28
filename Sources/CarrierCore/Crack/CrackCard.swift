/// A program in the crack prototype.
public struct CrackCard: Codable, Sendable, Equatable {
    public let id: String
    public let kind: CrackCardKind
    /// The symbol a symbol or dial card shows when it is played. A probe
    /// has none.
    public let symbol: String?

    public init(id: String, kind: CrackCardKind = .symbol, symbol: String?) {
        self.id = id
        self.kind = kind
        self.symbol = symbol
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, symbol
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decodeIfPresent(CrackCardKind.self, forKey: .kind) ?? .symbol
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
    }

    /// What the hand shows: `A`, `DIAL-A`, `PROBE`.
    public var label: String {
        switch kind {
        case .symbol: symbol ?? id
        case .dial: "DIAL-" + (symbol ?? "?")
        case .probe: "PROBE"
        }
    }
}

/// What a crack card does when it is played on a slot.
public enum CrackCardKind: String, Codable, Sendable, Equatable {
    /// Sits on the slot and shows its symbol.
    case symbol
    /// Sits on the slot like a symbol card, and can be turned to another
    /// symbol where it stands.
    case dial
    /// Reveals the slot's symbol in the code, then goes to the discard pile.
    case probe
}
