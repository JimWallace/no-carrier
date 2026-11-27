/// A machine's security layers, outermost first (kickoff §4).
public enum LayerKind: String, Codable, Sendable, CaseIterable {
    case firewall
    case auth
    case kernel

    public var label: String { rawValue.uppercased() }
}
