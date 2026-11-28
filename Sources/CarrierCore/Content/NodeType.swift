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

extension NodeType {
    /// What the type gives its owner, for a map key in every frontend:
    /// `REPAIR: +3 INT EACH TICK`. The numbers come from the rule set's
    /// tuning, so the key follows a balance change; `payloadName` is the
    /// name of the card a VIRUS node makes.
    public func meaning(tuning: NetworkTuning, payloadName: String) -> String {
        switch self {
        case .entry: "ENTRY: YOURS. LOSE IT, YOU LOSE"
        case .relay: "RELAY: +\(tuning.relayProxy) DEF IN EVERY FIGHT"
        case .repair: "REPAIR: +\(tuning.repairIntegrity) INT EACH TICK"
        case .virus: "VIRUS: +\(tuning.virusPayload) \(payloadName) EACH TICK"
        case .data: "DATA: AN UPGRADE WHEN TAKEN"
        case .root: "ROOT: TAKE IT TO WIN"
        }
    }
}
