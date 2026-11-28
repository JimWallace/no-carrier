/// Why the contract engine refused an action. A refused action changes
/// nothing.
public enum ContractRejectReason: Codable, Sendable, Equatable {
    case contractOver
    case wrongPhase
    case noSuchNode(node: Int)
    case alreadyOwned(node: Int)
    case notLinked(node: Int)
    case notContested(node: Int)
    case noSuchChoice(choice: Int)
    case storageFull
    case noSuchDeckCard(index: Int)
    case notDetected(node: Int)
    /// The action's mechanic is off in this contract's rules.
    case ruleOff(MechanicFlag)

    public var line: String {
        switch self {
        case .contractOver: "?CONTRACT CLOSED"
        case .wrongPhase: "?NOT NOW"
        case .noSuchNode(let node): "?NO NODE \(node)"
        case .alreadyOwned(let node): "?NODE \(node) IS YOURS"
        case .notLinked(let node): "?NODE \(node) IS NOT LINKED TO YOURS"
        case .notContested(let node): "?NODE \(node) IS NOT CONTESTED"
        case .noSuchChoice(let choice): "?NO CHOICE \(choice &+ 1)"
        case .storageFull: "?STORAGE FULL: DELETE A CARD FIRST"
        case .noSuchDeckCard(let index): "?NO DECK CARD \(index &+ 1)"
        case .notDetected(let node): "?NODE \(node) IS NOT A DETECTED UNKNOWN"
        case .ruleOff(let flag): "?\(flag.label) IS OFF IN THESE RULES"
        }
    }
}
