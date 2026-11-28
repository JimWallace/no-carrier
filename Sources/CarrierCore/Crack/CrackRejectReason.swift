/// Why the crack engine refused an action. The action changes nothing.
public enum CrackRejectReason: String, Codable, Sendable, Equatable {
    case over
    case noSuchCard
    case noSuchSlot
    case sameSlot
    case noEnergy

    /// What the player reads.
    public var label: String {
        switch self {
        case .over: "SESSION OVER"
        case .noSuchCard: "NO SUCH CARD"
        case .noSuchSlot: "NO SUCH SLOT"
        case .sameSlot: "SAME SLOT"
        case .noEnergy: "NOT ENOUGH ENERGY"
        }
    }
}
