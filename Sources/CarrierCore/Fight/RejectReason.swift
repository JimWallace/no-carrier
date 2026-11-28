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

extension RejectReason {
    /// Why a card cannot run, in a few characters, for a card's face:
    /// `NO CYC`, `NO RAM`, `KERNEL ONLY`.
    public var shortLabel: String {
        switch self {
        case .notEnoughCycles: "NO CYC"
        case .notEnoughRAM: "NO RAM"
        case .wrongLayer(_, let layer): "\(layer.label) ONLY"
        case .unplayable: "DEAD"
        case .fightOver: "OVER"
        case .noSuchCard, .unknownCard: "?"
        }
    }
}
