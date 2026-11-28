public import CarrierCore

/// A simple, sensible player. It is a yardstick for tuning between human
/// playtests, not an expert.
///
/// On the map it reinforces a contested node, rests on a REPAIR node when
/// Integrity is low, waits for PAYLOAD when every target behind a KERNEL is
/// out of reach, and otherwise attacks the cheapest target it can break,
/// favouring VIRUS, DATA and REPAIR nodes. In a fight it probes, shields
/// against the telegraphed attack, starts daemons, then hits as hard as it
/// can; it logs out of a fight that has gone on too long. It takes loot
/// that beats BRUTE.EXE and the CPU upgrade. It reads machines through the
/// fog.
///
/// Loud (`greedy`), it always CLAIMs. Quiet (`ghost`), it GHOSTs through
/// every node except the ones that pay for owning them (VIRUS, REPAIR,
/// ROOT), and it weighs each exploit's damage against its noise.
public struct GreedyBot: ContractBot {
    public let name: String
    /// Fight turns before it logs out.
    public var patience: Int
    public let quiet: Bool

    public init(quiet: Bool = false, patience: Int = 12) {
        self.quiet = quiet
        self.patience = patience
        name = quiet ? "ghost" : "greedy"
    }

    public mutating func choose(_ state: ContractState, engine: ContractEngine) -> ContractAction {
        let action: ContractAction
        switch state.phase {
        case .map: action = chooseOnMap(state, engine: engine)
        case .fight(_, let fight, _): action = .fight(chooseInFight(fight, engine: engine.fightEngine))
        case .accessChoice(let node, _, _):
            let worthOwning: Set<NodeType> = [.virus, .repair, .root]
            action = !quiet || worthOwning.contains(state.network.nodes[node].type) ? .claim : .ghost
        case .reward(_, let choices): action = chooseLoot(choices, state: state, content: engine.content)
        case .upgrade(_, let choices, _):
            action = .chooseUpgrade(choice: choices.firstIndex { $0.component == .cpu } ?? 0)
        case .over: action = .wait
        }
        // Never send what the engine would refuse.
        if engine.rejection(for: action, in: state) == nil { return action }
        return LegalActions.list(state, engine: engine).last ?? .wait
    }

    // MARK: - Map

    private func chooseOnMap(_ state: ContractState, engine: ContractEngine) -> ContractAction {
        let nodes = state.network.nodes
        if let entry = nodes.first(where: { $0.owner == .player && $0.contested && $0.type == .entry }) {
            return .reinforce(node: entry.index)
        }
        if let contested = nodes.first(where: { $0.owner == .player && $0.contested }) {
            return .reinforce(node: contested.index)
        }
        let ownsRepair = nodes.contains { $0.owner == .player && $0.type == .repair }
        if ownsRepair && state.integrity * 5 < state.rig.maxIntegrity * 2 {
            return .wait
        }
        let content = engine.content
        let payloadID = content.tuning.network.payloadCard
        let payloadDamage = content.card(payloadID).map(CardValue.kernelDamage) ?? 0
        let kernelReach = state.deck.count { $0 == payloadID } * payloadDamage

        var best: (node: Int, score: Int)?
        for index in state.network.attackable {
            let machine = nodes[index].machine
            let kernel = machine.layers.first { $0.kind == .kernel }?.hp ?? 0
            guard kernel <= kernelReach else { continue }
            if nodes[index].type == .root && state.integrity * 3 < state.rig.maxIntegrity * 2 { continue }
            let outer = machine.layers.filter { $0.kind != .kernel }.reduce(0) { $0 + $1.hp }
            let score = outer + 6 * machine.ice.count - typeBonus(nodes[index].type)
            if best == nil || score < (best?.score ?? 0) {
                best = (index, score)
            }
        }
        if let best { return .attack(node: best.node) }
        return .wait
    }

    private func typeBonus(_ type: NodeType) -> Int {
        switch type {
        case .root: 100
        case .virus: 12
        case .data: 10
        case .repair: 8
        case .relay: 6
        case .entry: 0
        }
    }

    // MARK: - Fight

    private func chooseInFight(_ fight: FightState, engine: Engine) -> Action {
        if fight.turn > patience { return .logout }
        let content = engine.content
        let playable = fight.hand.indices.filter { engine.rejection(forPlaying: $0, in: fight) == nil }
        func card(_ index: Int) -> CardDefinition? { content.card(fight.hand[index].cardID) }
        func first(_ test: (CardDefinition) -> Bool) -> Int? {
            playable.first { card($0).map(test) ?? false }
        }
        let incoming = engine.telegraph(fight).flatMap(\.intents).reduce(0) { total, intent in
            if case .attack(let amount) = intent { return total + amount }
            return total
        }

        if let free = first({ $0.cost == .fixed(0) }) { return .play(handIndex: free) }
        if fight.proxy < incoming,
            let shield = playable.filter({ card($0)?.type == .proxy })
                .max(by: { (card($0).map(CardValue.shield) ?? 0) < (card($1).map(CardValue.shield) ?? 0) })
        {
            return .play(handIndex: shield)
        }
        if let daemon = first({ $0.type == .daemon }) { return .play(handIndex: daemon) }
        if let payload = first({ $0.type == .payload }) { return .play(handIndex: payload) }
        // Quiet, a point of noise costs three of damage.
        func worth(_ index: Int) -> Int {
            guard let card = card(index) else { return 0 }
            let damage = CardValue.damage(card, cycles: fight.cycles)
            return quiet ? damage - 3 * max(0, card.noise(cycles: fight.cycles)) : damage
        }
        if fight.currentLayer != .kernel,
            let exploit = playable.filter({ card($0)?.type == .exploit }).max(by: { worth($0) < worth($1) })
        {
            return .play(handIndex: exploit)
        }
        if let script = first({ $0.type == .script }) { return .play(handIndex: script) }
        if incoming > 0, let shield = first({ $0.type == .proxy }) { return .play(handIndex: shield) }
        return .endTurn
    }

    // MARK: - Loot

    private func chooseLoot(_ choices: [String], state: ContractState, content: ContentPack) -> ContractAction {
        guard state.deck.count < state.storage - 1 else { return .skipReward }
        var best: (index: Int, score: Int)?
        for (index, id) in choices.enumerated() {
            guard let card = content.card(id) else { continue }
            let score = CardValue.score(card, rigCycles: state.rig.cycles)
            if best == nil || score > (best?.score ?? 0) {
                best = (index, score)
            }
        }
        guard let best, best.score > 60 else { return .skipReward }
        return .takeReward(choice: best.index, replacing: nil)
    }
}
