/// What a daemon card does while it runs. It holds `ram` of the rig's RAM
/// until the fight ends or ICE purges it.
public struct DaemonSpec: Codable, Sendable, Equatable {
    public var ram: Int
    public var onTurnStart: [Effect]
    public var passives: [Passive]

    public init(ram: Int, onTurnStart: [Effect] = [], passives: [Passive] = []) {
        self.ram = ram
        self.onTurnStart = onTurnStart
        self.passives = passives
    }

    private enum CodingKeys: String, CodingKey {
        case ram
        case onTurnStart
        case passives
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ram = try container.decode(Int.self, forKey: .ram)
        onTurnStart = try container.decodeIfPresent([Effect].self, forKey: .onTurnStart) ?? []
        passives = try container.decodeIfPresent([Passive].self, forKey: .passives) ?? []
    }

    public var summary: String {
        let parts = onTurnStart.map { "TURN: \($0.summary)" } + passives.map(\.summary)
        return parts.joined(separator: ", ")
    }
}
