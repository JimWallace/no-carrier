public import CarrierCore

/// A fixed, simple way to play a contract, for golden transcripts:
/// reinforce a contested node, else attack the weakest linked node; in a
/// fight, run the first card that can run, else end the turn, and log out
/// of a fight that has gone on for `patience` turns; take the first loot
/// unless Storage is full; take the first upgrade.
public struct GreedyContractBot {
    public let engine: ContractEngine
    public let patience: Int

    public init(engine: ContractEngine, patience: Int = 15) {
        self.engine = engine
        self.patience = patience
    }

    public func choose(_ state: ContractState) -> ContractAction {
        switch state.phase {
        case .map:
            if let contested = state.network.nodes.firstIndex(where: { $0.owner == .player && $0.contested }) {
                return .reinforce(node: contested)
            }
            let targets = state.network.attackable.sorted { lhs, rhs in
                let left = state.network.nodes[lhs].machine.layers.reduce(0) { $0 + $1.hp }
                let right = state.network.nodes[rhs].machine.layers.reduce(0) { $0 + $1.hp }
                return left == right ? lhs < rhs : left < right
            }
            return targets.first.map { .attack(node: $0) } ?? .wait
        case .fight(_, let fight, _):
            if fight.turn > patience { return .fight(.logout) }
            let playable = fight.hand.indices.first {
                engine.rejection(forPlaying: $0, in: state) == nil
            }
            return .fight(playable.map { .play(handIndex: $0) } ?? .endTurn)
        case .reward:
            return state.deck.count < state.storage ? .takeReward(choice: 0, replacing: nil) : .skipReward
        case .upgrade:
            return .chooseUpgrade(choice: 0)
        case .accessChoice:
            return .claim
        case .over:
            return .wait
        }
    }

    /// Plays from `state` until the contract ends or `limit` actions pass.
    public func play(
        _ state: ContractState, limit: Int = 2000
    ) -> (ContractState, [ContractAction], [ContractEvent]) {
        var current = state
        var actions: [ContractAction] = []
        var events: [ContractEvent] = []
        while current.outcome == nil && actions.count < limit {
            let action = choose(current)
            actions.append(action)
            let result = engine.apply(action, to: current)
            current = result.0
            events += result.1
        }
        return (current, actions, events)
    }
}
