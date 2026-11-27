public import CarrierCore

/// A way of playing a contract. A bot may keep its own state (the random
/// bot keeps a PRNG), so choosing is mutating.
public protocol ContractBot: Sendable {
    var name: String { get }
    mutating func choose(_ state: ContractState, engine: ContractEngine) -> ContractAction
}
