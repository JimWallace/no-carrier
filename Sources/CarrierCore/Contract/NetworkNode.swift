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
    /// The sysop has announced CONTEST on this node (the player's), or
    /// REVOKE on it (one the player has access to). REINFORCE clears it.
    public var contested: Bool
    /// The player breached FIREWALL and AUTH and chose GHOST: they can move
    /// through it, but it is not theirs (addendum 01, §2.2).
    public var accessed: Bool
    public var visibility: Visibility
    /// A DATA node gives its upgrade once.
    public var upgradeTaken: Bool

    /// The player owns it or has access to it.
    public var isFoothold: Bool { owner == .player || accessed }

    public init(index: Int, column: Int, row: Int, type: NodeType, owner: NodeOwner, machine: Machine) {
        self.index = index
        self.column = column
        self.row = row
        self.type = type
        self.owner = owner
        self.machine = machine
        contested = false
        accessed = false
        visibility = .scanned
        upgradeTaken = false
    }
}
