/// Why the crack engine refused an action. The action changes nothing.
public enum CrackRejectReason: String, Codable, Sendable, Equatable {
    case over
    case noSuchCard
    case noSuchSlot
    case sameSlot
    case noEnergy
    case notADial
    case unknownSymbol
    case alreadyShown
    case alreadyKnown
    case emptySlot
    case needsSlot
    case needsNoSlot

    /// What the player reads.
    public var label: String {
        switch self {
        case .over: "SESSION OVER"
        case .noSuchCard: "NO SUCH CARD"
        case .noSuchSlot: "NO SUCH SLOT"
        case .sameSlot: "SAME SLOT"
        case .noEnergy: "NOT ENOUGH ENERGY"
        case .notADial: "NO DIAL IN THAT SLOT"
        case .unknownSymbol: "NO SUCH SYMBOL"
        case .alreadyShown: "DIAL ALREADY SHOWS THAT"
        case .alreadyKnown: "SLOT ALREADY KNOWN"
        case .emptySlot: "THAT SLOT IS EMPTY"
        case .needsSlot: "PLAY IT ON A SLOT: CARD SLOT"
        case .needsNoSlot: "PLAY IT ON ITS OWN: JUST THE CARD"
        }
    }
}
