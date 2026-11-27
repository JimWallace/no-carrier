/// Who owns a node, as far as generating its machine is concerned. A sysop
/// node has a KERNEL layer; ROOT is the boss machine.
public enum NodeRole: String, Codable, Sendable, CaseIterable {
    case neutral
    case sysop
    case root

    public var label: String { rawValue.uppercased() }
}
