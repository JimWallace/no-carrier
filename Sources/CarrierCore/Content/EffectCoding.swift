/// The JSON form of `Effect`: an object with an `op` and the fields that op
/// uses, for example `{"op": "damage", "amount": 3, "hits": 2}`.
extension Effect: Codable {
    private enum CodingKeys: String, CodingKey {
        case op
        case amount
        case hits
        case layer
        case then
        case otherwise = "else"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let op = try container.decode(String.self, forKey: .op)
        func amount() throws -> Int { try container.decode(Int.self, forKey: .amount) }
        switch op {
        case "damage":
            let hits = try container.decodeIfPresent(Int.self, forKey: .hits) ?? 1
            self = .damage(amount: try amount(), hits: hits)
        case "damagePerCycle": self = .damagePerCycle(amount: try amount())
        case "kernelDamage": self = .kernelDamage(amount: try amount())
        case "shield": self = .shield(amount: try amount())
        case "draw": self = .draw(amount: try amount())
        case "trace": self = .trace(amount: try amount())
        case "cyclesNextTurn": self = .cyclesNextTurn(amount: try amount())
        case "probe": self = .probe
        case "deleteMalware": self = .deleteMalware(amount: try amount())
        case "retaliate": self = .retaliate(amount: try amount())
        case "transferBoost": self = .transferBoost(amount: try amount())
        case "traceShield": self = .traceShield(amount: try amount())
        case "ifLayer":
            self = .ifLayer(
                layer: try container.decode(LayerKind.self, forKey: .layer),
                then: try container.decodeIfPresent([Self].self, forKey: .then) ?? [],
                otherwise: try container.decodeIfPresent([Self].self, forKey: .otherwise) ?? []
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .op, in: container, debugDescription: "Unknown effect op \"\(op)\".")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .damage(let amount, let hits):
            try container.encode("damage", forKey: .op)
            try container.encode(amount, forKey: .amount)
            if hits != 1 { try container.encode(hits, forKey: .hits) }
        case .damagePerCycle(let amount): try encode("damagePerCycle", amount, into: &container)
        case .kernelDamage(let amount): try encode("kernelDamage", amount, into: &container)
        case .shield(let amount): try encode("shield", amount, into: &container)
        case .draw(let amount): try encode("draw", amount, into: &container)
        case .trace(let amount): try encode("trace", amount, into: &container)
        case .cyclesNextTurn(let amount): try encode("cyclesNextTurn", amount, into: &container)
        case .probe: try container.encode("probe", forKey: .op)
        case .deleteMalware(let amount): try encode("deleteMalware", amount, into: &container)
        case .retaliate(let amount): try encode("retaliate", amount, into: &container)
        case .transferBoost(let amount): try encode("transferBoost", amount, into: &container)
        case .traceShield(let amount): try encode("traceShield", amount, into: &container)
        case .ifLayer(let layer, let then, let otherwise):
            try container.encode("ifLayer", forKey: .op)
            try container.encode(layer, forKey: .layer)
            try container.encode(then, forKey: .then)
            try container.encode(otherwise, forKey: .otherwise)
        }
    }

    private func encode(
        _ op: String, _ amount: Int, into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        try container.encode(op, forKey: .op)
        try container.encode(amount, forKey: .amount)
    }
}
