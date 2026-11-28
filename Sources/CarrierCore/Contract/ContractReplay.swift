/// A recorded contract: the seed and every action. With the same content it
/// reproduces the contract exactly. `carrier play --record` writes one;
/// `carrier replay` reads it.
public struct ContractReplay: Codable, Sendable, Equatable {
    public static let currentFormat = 1
    /// Tells a contract replay from a fight replay.
    public static let kindName = "contract"

    public var kind: String
    public var format: Int
    public var carrierVersion: String
    public var seed: UInt64
    /// The objective id. Nil in replays from before objectives existed,
    /// which were all TAKEOVER, the default objective.
    public var objective: String?
    /// The composed rules the contract ran under (addendum 02, §1). Nil in
    /// replays from before rule sets, which ran under the objective's
    /// default rules.
    public var rules: RuleSet?
    public var actions: [ContractAction]

    public init(
        carrierVersion: String, seed: UInt64, objective: String?, rules: RuleSet? = nil,
        actions: [ContractAction] = []
    ) {
        kind = Self.kindName
        format = Self.currentFormat
        self.carrierVersion = carrierVersion
        self.seed = seed
        self.objective = objective
        self.rules = rules
        self.actions = actions
    }
}
