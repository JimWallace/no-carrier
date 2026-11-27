/// A card's cycle cost. In JSON: a number, `"X"` (spend every cycle), or
/// `null` (unplayable, as malware is).
public enum CardCost: Sendable, Equatable {
    case fixed(Int)
    case x
    case unplayable

    public var label: String {
        switch self {
        case .fixed(let value): String(value)
        case .x: "X"
        case .unplayable: "-"
        }
    }
}

extension CardCost: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .unplayable
        } else if let value = try? container.decode(Int.self) {
            self = .fixed(value)
        } else if let text = try? container.decode(String.self), text == "X" {
            self = .x
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "A cost is a number, \"X\" or null.")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .fixed(let value): try container.encode(value)
        case .x: try container.encode("X")
        case .unplayable: try container.encodeNil()
        }
    }
}
