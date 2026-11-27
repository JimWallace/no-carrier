/// One action an ICE program telegraphs and then carries out at the end of
/// the player's turn (kickoff §4, "ICE").
public enum Intent: Sendable, Equatable {
    /// Damage to Proxy first, then Integrity.
    case attack(amount: Int)
    /// Adds to global Trace, scaled by the machine's modem.
    case trace(amount: Int)
    /// Adds HP to the current layer.
    case harden(amount: Int)
    /// Removes the player's largest daemon.
    case purgeDaemon
    /// Adds a card (malware) to the player's discard pile.
    case injectMalware(cardID: String)

    public var label: String {
        switch self {
        case .attack(let amount): "ATTACK \(amount)"
        case .trace(let amount): "TRACE +\(amount)"
        case .harden(let amount): "HARDEN \(amount)"
        case .purgeDaemon: "PURGE DAEMON"
        case .injectMalware: "INJECT MALWARE"
        }
    }
}

extension Intent: Codable {
    private enum CodingKeys: String, CodingKey {
        case op
        case amount
        case card
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let op = try container.decode(String.self, forKey: .op)
        switch op {
        case "attack": self = .attack(amount: try container.decode(Int.self, forKey: .amount))
        case "trace": self = .trace(amount: try container.decode(Int.self, forKey: .amount))
        case "harden": self = .harden(amount: try container.decode(Int.self, forKey: .amount))
        case "purgeDaemon": self = .purgeDaemon
        case "injectMalware": self = .injectMalware(cardID: try container.decode(String.self, forKey: .card))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .op, in: container, debugDescription: "Unknown intent op \"\(op)\".")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .attack(let amount):
            try container.encode("attack", forKey: .op)
            try container.encode(amount, forKey: .amount)
        case .trace(let amount):
            try container.encode("trace", forKey: .op)
            try container.encode(amount, forKey: .amount)
        case .harden(let amount):
            try container.encode("harden", forKey: .op)
            try container.encode(amount, forKey: .amount)
        case .purgeDaemon:
            try container.encode("purgeDaemon", forKey: .op)
        case .injectMalware(let cardID):
            try container.encode("injectMalware", forKey: .op)
            try container.encode(cardID, forKey: .card)
        }
    }
}
