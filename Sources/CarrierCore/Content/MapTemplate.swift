/// A hand-authored network layout (kickoff §3, "Map generation"). Procgen
/// fills in the node types the template leaves open, and every machine.
///
/// Nodes sit on a small grid, and links join grid neighbours only, so the
/// 40-column map can draw them with `-` and `|`.
public struct MapTemplate: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var nodes: [MapSlot]
    /// Pairs of node indices.
    public var links: [[Int]]

    public init(id: String, nodes: [MapSlot], links: [[Int]]) {
        self.id = id
        self.nodes = nodes
        self.links = links
    }
}

/// One node position in a template.
public struct MapSlot: Codable, Sendable, Equatable {
    public var column: Int
    public var row: Int
    /// Who owns the node when the contract starts.
    public var owner: NodeOwner
    /// A fixed type, or nil for procgen to choose.
    public var type: NodeType?

    public init(column: Int, row: Int, owner: NodeOwner, type: NodeType? = nil) {
        self.column = column
        self.row = row
        self.owner = owner
        self.type = type
    }
}

/// Who holds a node (kickoff §3, "Node ownership").
public enum NodeOwner: String, Codable, Sendable, Equatable {
    case player
    case sysop
    case neutral
}
