/// Why the engine refused an action. A refused action changes nothing.
public enum RejectReason: Codable, Sendable, Equatable {
    case fightOver
    case noSuchCard(handIndex: Int)
    case unplayable(cardID: String)
    case notEnoughCycles(cardID: String, cost: Int, cycles: Int)
    case notEnoughRAM(cardID: String, needed: Int, free: Int)
    case wrongLayer(cardID: String, required: LayerKind)
    case unknownCard(cardID: String)
}
