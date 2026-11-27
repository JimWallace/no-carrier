/// A standing modifier from a running daemon.
public enum Passive: Sendable, Equatable {
    /// Exploit hits deal `amount` more damage (KEYLOGGER.DMN).
    case exploitBonus(amount: Int)
    /// ICE TRACE intents add `amount` less Trace (CLOAK.DMN).
    case iceTraceReduction(amount: Int)

    public var summary: String {
        switch self {
        case .exploitBonus(let amount): "EXPLOITS +\(amount) DMG"
        case .iceTraceReduction(let amount): "ICE TRACE -\(amount)"
        }
    }
}

extension Passive: Codable {
    private enum CodingKeys: String, CodingKey {
        case op
        case amount
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let op = try container.decode(String.self, forKey: .op)
        let amount = try container.decode(Int.self, forKey: .amount)
        switch op {
        case "exploitBonus": self = .exploitBonus(amount: amount)
        case "iceTraceReduction": self = .iceTraceReduction(amount: amount)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .op, in: container, debugDescription: "Unknown passive op \"\(op)\".")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .exploitBonus(let amount):
            try container.encode("exploitBonus", forKey: .op)
            try container.encode(amount, forKey: .amount)
        case .iceTraceReduction(let amount):
            try container.encode("iceTraceReduction", forKey: .op)
            try container.encode(amount, forKey: .amount)
        }
    }
}
