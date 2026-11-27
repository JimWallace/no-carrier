public import CarrierCore

/// Picks uniformly from the legal actions. A floor for the other bots: a
/// strategy that does no better than this one is no strategy.
public struct RandomBot: ContractBot {
    public let name = "random"
    private var rng: Xoshiro256StarStar

    public init(seed: UInt64) {
        rng = Xoshiro256StarStar(seed: Seed.derive(seed, "random-bot"))
    }

    public mutating func choose(_ state: ContractState, engine: ContractEngine) -> ContractAction {
        rng.pick(LegalActions.list(state, engine: engine)) ?? .wait
    }
}
