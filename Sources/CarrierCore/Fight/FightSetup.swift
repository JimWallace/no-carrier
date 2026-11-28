/// Everything a fight starts from. A contract (M3) builds one per node; the
/// `carrier fight` sandbox builds one from a seed.
public struct FightSetup: Codable, Sendable, Equatable {
    public var seed: UInt64
    public var machine: Machine
    /// Card ids, in deck order before the shuffle.
    public var deck: [String]
    public var rig: Rig
    public var integrity: Int
    public var trace: Int
    /// Proxy at the start of the first turn (RELAY nodes, M3).
    public var startingProxy: Int
    /// A file to copy instead of capturing the node (EXFILTRATION).
    public var transfer: TransferProgress?

    public init(
        seed: UInt64, machine: Machine, deck: [String], rig: Rig, integrity: Int, trace: Int,
        startingProxy: Int = 0, transfer: TransferProgress? = nil
    ) {
        self.seed = seed
        self.machine = machine
        self.deck = deck
        self.rig = rig
        self.integrity = integrity
        self.trace = trace
        self.startingProxy = startingProxy
        self.transfer = transfer
    }
}
