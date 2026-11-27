/// What a network node gives its owner (kickoff §3, "Node types").
public enum NodeType: String, Codable, Sendable, CaseIterable {
    case entry
    case relay
    case repair
    case virus
    case data
    case root

    public var label: String { rawValue.uppercased() }

    /// One letter for the map.
    public var mapLetter: String {
        switch self {
        case .entry: "E"
        case .relay: "R"
        case .repair: "H"
        case .virus: "V"
        case .data: "D"
        case .root: "X"
        }
    }
}
