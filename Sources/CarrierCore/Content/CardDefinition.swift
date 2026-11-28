/// A card as the content JSON defines it. Fight state holds `CardInstance`s
/// that point at one of these by `id`.
public struct CardDefinition: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    /// What the player sees and types: upper case, at most 14 characters.
    public var name: String
    public var type: CardType
    public var cost: CardCost
    public var tags: [ExploitTag]
    public var effects: [Effect]
    public var daemon: DaemonSpec?
    /// Goes to the exhaust pile when played, out of the fight (PROBE).
    public var exhaust: Bool
    /// Leaves the deck for good when played (PAYLOAD).
    public var consumed: Bool
    /// Playable only while this is the current layer (PAYLOAD: KERNEL).
    public var requiresLayer: LayerKind?
    /// Applies when the card is still in hand at the end of a turn (TRACER).
    public var endOfTurnInHand: [Effect]
    /// Removed from the deck when the fight ends (malware).
    public var temporary: Bool
    /// Alert added when the card is played (addendum 01, §2.1). Negative
    /// lowers Alert (SPOOF), and does not count as making noise.
    public var noise: Int
    /// More Alert for each cycle an X cost spent (DICTIONARY).
    public var noisePerCycle: Int

    public init(
        id: String,
        name: String,
        type: CardType,
        cost: CardCost,
        tags: [ExploitTag] = [],
        effects: [Effect] = [],
        daemon: DaemonSpec? = nil,
        exhaust: Bool = false,
        consumed: Bool = false,
        requiresLayer: LayerKind? = nil,
        endOfTurnInHand: [Effect] = [],
        temporary: Bool = false,
        noise: Int = 0,
        noisePerCycle: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.cost = cost
        self.tags = tags
        self.effects = effects
        self.daemon = daemon
        self.exhaust = exhaust
        self.consumed = consumed
        self.requiresLayer = requiresLayer
        self.endOfTurnInHand = endOfTurnInHand
        self.temporary = temporary
        self.noise = noise
        self.noisePerCycle = noisePerCycle
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, type, cost, tags, effects, daemon, exhaust, consumed
        case requiresLayer, endOfTurnInHand, temporary, noise, noisePerCycle
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(CardType.self, forKey: .type)
        cost = try container.decodeIfPresent(CardCost.self, forKey: .cost) ?? .unplayable
        tags = try container.decodeIfPresent([ExploitTag].self, forKey: .tags) ?? []
        effects = try container.decodeIfPresent([Effect].self, forKey: .effects) ?? []
        daemon = try container.decodeIfPresent(DaemonSpec.self, forKey: .daemon)
        exhaust = try container.decodeIfPresent(Bool.self, forKey: .exhaust) ?? false
        consumed = try container.decodeIfPresent(Bool.self, forKey: .consumed) ?? false
        requiresLayer = try container.decodeIfPresent(LayerKind.self, forKey: .requiresLayer)
        endOfTurnInHand = try container.decodeIfPresent([Effect].self, forKey: .endOfTurnInHand) ?? []
        temporary = try container.decodeIfPresent(Bool.self, forKey: .temporary) ?? false
        noise = try container.decodeIfPresent(Int.self, forKey: .noise) ?? 0
        noisePerCycle = try container.decodeIfPresent(Int.self, forKey: .noisePerCycle) ?? 0
    }

    /// The Alert a play adds, with `cycles` spent on an X cost.
    public func noise(cycles: Int) -> Int {
        noise + noisePerCycle * cycles
    }

    /// One line of rules text for a 40-column card list.
    public var summary: String {
        var parts: [String] = []
        if !effects.isEmpty { parts.append(Effect.summary(of: effects)) }
        if let daemon { parts.append("RAM \(daemon.ram); " + daemon.summary) }
        if !endOfTurnInHand.isEmpty { parts.append("IN HAND AT END: " + Effect.summary(of: endOfTurnInHand)) }
        if let requiresLayer { parts.append("ONLY VS \(requiresLayer.label)") }
        if exhaust { parts.append("EXHAUST") }
        if consumed { parts.append("CONSUMED") }
        if cost == .unplayable { parts.append("UNPLAYABLE") }
        if noisePerCycle != 0 {
            parts.append("NOISE \(noisePerCycle)/CYCLE")
        } else if noise != 0 {
            parts.append("NOISE \(noise)")
        }
        return parts.joined(separator: "; ")
    }
}
