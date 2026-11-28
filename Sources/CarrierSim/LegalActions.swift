public import CarrierCore

/// Every action the contract engine would accept now, in a fixed order.
/// The random bot picks from these; tests check the other bots against
/// them.
public enum LegalActions {
    public static func list(_ state: ContractState, engine: ContractEngine) -> [ContractAction] {
        let candidates: [ContractAction]
        switch state.phase {
        case .map:
            let reinforce = state.network.nodes.filter { $0.isFoothold && $0.contested }
                .map { ContractAction.reinforce(node: $0.index) }
            let scans = state.network.nodes.filter { $0.visibility == .detected }
                .map { ContractAction.scan(node: $0.index) }
            candidates = state.network.attackable.map { .attack(node: $0) } + reinforce + scans + [.wait, .jackOut]
        case .accessChoice:
            candidates = [.claim, .ghost]
        case .fight(_, let fight, _):
            candidates = fight.hand.indices.map { .fight(.play(handIndex: $0)) } + [.fight(.endTurn), .fight(.logout)]
        case .reward(_, let choices):
            let replacing: Int? = state.deck.count >= state.storage ? 0 : nil
            candidates = choices.indices.map { .takeReward(choice: $0, replacing: replacing) } + [.skipReward]
        case .upgrade(_, let choices, _):
            candidates = choices.indices.map { .chooseUpgrade(choice: $0) }
        case .over:
            candidates = []
        }
        return candidates.filter { engine.rejection(for: $0, in: state) == nil }
    }
}
