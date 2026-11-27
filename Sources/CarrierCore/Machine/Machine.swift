/// A generated computer: everything a fight needs, and the flavour that
/// `carrier gen` prints. `CarrierGen` builds one from a seed; the same seed
/// and content always give the same machine.
public struct Machine: Codable, Sendable, Equatable {
    public var seed: UInt64
    public var role: NodeRole
    public var orgName: String
    public var orgKind: String
    public var hostname: String
    public var osFamilyID: String
    public var osName: String
    public var osVersion: String
    public var cpu: CPUModel
    public var ramMB: Int
    public var modem: ModemModel
    public var weak: [ExploitTag]
    public var resist: [ExploitTag]
    public var layers: [SecurityLayer]
    /// ICE program ids, in the order they act.
    public var ice: [String]
    public var users: [String]
    /// Paths, in display order.
    public var filesystem: [String]

    public init(
        seed: UInt64,
        role: NodeRole,
        orgName: String,
        orgKind: String,
        hostname: String,
        osFamilyID: String,
        osName: String,
        osVersion: String,
        cpu: CPUModel,
        ramMB: Int,
        modem: ModemModel,
        weak: [ExploitTag],
        resist: [ExploitTag],
        layers: [SecurityLayer],
        ice: [String],
        users: [String],
        filesystem: [String]
    ) {
        self.seed = seed
        self.role = role
        self.orgName = orgName
        self.orgKind = orgKind
        self.hostname = hostname
        self.osFamilyID = osFamilyID
        self.osName = osName
        self.osVersion = osVersion
        self.cpu = cpu
        self.ramMB = ramMB
        self.modem = modem
        self.weak = weak
        self.resist = resist
        self.layers = layers
        self.ice = ice
        self.users = users
        self.filesystem = filesystem
    }
}
