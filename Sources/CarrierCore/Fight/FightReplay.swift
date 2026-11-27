/// A recorded sandbox fight: the seed, the machine role and every action.
/// With the same content, it reproduces the fight exactly (kickoff §8,
/// "Replays"). `carrier fight --record` writes one; `carrier replay` plays it.
public struct FightReplay: Codable, Sendable, Equatable {
    /// Bumped when the file layout changes.
    public static let currentFormat = 1

    public var format: Int
    /// The `CarrierVersion` that recorded it. A replay from another version
    /// may diverge if the rules or content changed in between.
    public var carrierVersion: String
    public var seed: UInt64
    public var role: NodeRole
    /// The `--payload` count, or nil for the tuning default.
    public var payload: Int?
    public var actions: [Action]

    public init(
        carrierVersion: String, seed: UInt64, role: NodeRole, payload: Int? = nil, actions: [Action] = []
    ) {
        format = Self.currentFormat
        self.carrierVersion = carrierVersion
        self.seed = seed
        self.role = role
        self.payload = payload
        self.actions = actions
    }
}
