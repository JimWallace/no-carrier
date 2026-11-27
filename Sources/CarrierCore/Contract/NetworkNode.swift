/// One node of a contract's network.
public struct NetworkNode: Codable, Sendable, Equatable {
    /// The node's number, which the player types (0 to 9).
    public let index: Int
    public let column: Int
    public let row: Int
    public var type: NodeType
    public var owner: NodeOwner
    /// The machine as it stands between fights: HARDEN and SPAWN ICE change
    /// it; a fight that ends in LOGOUT does not.
    public var machine: Machine
    /// The sysop has announced CONTEST on this node.
    public var contested: Bool
    /// A DATA node gives its upgrade once.
    public var upgradeTaken: Bool

    public init(index: Int, column: Int, row: Int, type: NodeType, owner: NodeOwner, machine: Machine) {
        self.index = index
        self.column = column
        self.row = row
        self.type = type
        self.owner = owner
        self.machine = machine
        contested = false
        upgradeTaken = false
    }
}
