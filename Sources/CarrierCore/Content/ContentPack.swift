/// Every piece of content the rules and generators read: the parsed content
/// JSON. `CarrierContent` builds one from files; tests can build one in code.
public struct ContentPack: Sendable, Equatable {
    public let cards: [CardDefinition]
    public let ice: [ICEDefinition]
    public let osFamilies: [OSFamily]
    public let hardware: HardwareCatalog
    public let orgs: [OrgTemplate]
    public let tuning: Tuning
    public let maps: [MapTemplate]

    // Lookup tables. Only ever read by key, never iterated, so their
    // per-process order cannot reach a rule.
    private let cardIndex: [String: Int]
    private let iceIndex: [String: Int]
    private let osIndex: [String: Int]

    public init(
        cards: [CardDefinition],
        ice: [ICEDefinition],
        osFamilies: [OSFamily],
        hardware: HardwareCatalog,
        orgs: [OrgTemplate],
        tuning: Tuning,
        maps: [MapTemplate] = []
    ) {
        self.cards = cards
        self.ice = ice
        self.osFamilies = osFamilies
        self.hardware = hardware
        self.orgs = orgs
        self.tuning = tuning
        self.maps = maps
        cardIndex = Self.index(cards.map(\.id))
        iceIndex = Self.index(ice.map(\.id))
        osIndex = Self.index(osFamilies.map(\.id))
    }

    public func card(_ id: String) -> CardDefinition? {
        cardIndex[id].map { cards[$0] }
    }

    public func iceDefinition(_ id: String) -> ICEDefinition? {
        iceIndex[id].map { ice[$0] }
    }

    public func osFamily(_ id: String) -> OSFamily? {
        osIndex[id].map { osFamilies[$0] }
    }

    public func cpu(named name: String) -> CPUModel? {
        hardware.cpus.first { $0.name == name }
    }

    public func modem(named name: String) -> ModemModel? {
        hardware.modems.first { $0.name == name }
    }

    /// The first entry wins, so a duplicate id cannot hide the original;
    /// `validate()` reports the duplicate.
    private static func index(_ ids: [String]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (offset, id) in ids.enumerated() where result[id] == nil {
            result[id] = offset
        }
        return result
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.cards == rhs.cards && lhs.ice == rhs.ice && lhs.osFamilies == rhs.osFamilies
            && lhs.hardware == rhs.hardware && lhs.orgs == rhs.orgs && lhs.tuning == rhs.tuning
            && lhs.maps == rhs.maps
    }
}
