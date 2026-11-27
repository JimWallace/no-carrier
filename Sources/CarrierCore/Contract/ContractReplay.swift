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
    public var actions: [ContractAction]

    public init(carrierVersion: String, seed: UInt64, actions: [ContractAction] = []) {
        kind = Self.kindName
        format = Self.currentFormat
        self.carrierVersion = carrierVersion
        self.seed = seed
        self.actions = actions
    }
}
