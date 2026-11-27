/// What the sysop does at the end of a tick, announced one tick ahead
/// (kickoff §3, "Sysop phase").
public enum SysopIntent: Codable, Sendable, Equatable {
    /// The node flips to the sysop unless the player REINFORCEs it.
    case contest(node: Int)
    /// Adds to the node's outermost standing layer.
    case harden(node: Int)
    /// Adds an ICE program to the node.
    case spawnICE(node: Int, iceID: String)
    /// Trace goes up.
    case sweep

    public func label(content: ContentPack) -> String {
        switch self {
        case .contest(let node): "CONTEST NODE \(node)"
        case .harden(let node): "HARDEN NODE \(node)"
        case .spawnICE(let node, let iceID):
            "SPAWN \(content.iceDefinition(iceID)?.name ?? iceID) ON NODE \(node)"
        case .sweep: "SWEEP (TRACE +\(content.tuning.network.sweepTrace))"
        }
    }
}
