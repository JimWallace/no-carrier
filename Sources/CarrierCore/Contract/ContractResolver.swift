/// Works one contract action through a mutable copy of the state.
struct ContractResolver {
    var state: ContractState
    let engine: ContractEngine
    var events: [ContractEvent] = []

    init(state: ContractState, engine: ContractEngine) {
        self.state = state
        self.engine = engine
    }

    var content: ContentPack { engine.content }
    var network: NetworkTuning { content.tuning.network }

    mutating func emit(_ event: ContractEvent) {
        events.append(event)
    }

    mutating func end(_ outcome: ContractOutcome) {
        state.phase = .over(outcome)
        emit(.contractEnded(outcome: outcome))
    }

    mutating func changeTrace(by delta: Int) {
        let total = max(0, state.trace + delta)
        guard total != state.trace else { return }
        emit(.traceChanged(by: total - state.trace, total: total))
        state.trace = total
    }

    // MARK: - Checking

    func rejection(for action: ContractAction) -> ContractRejectReason? {
        switch (action, state.phase) {
        case (.attack(let node), .map):
            guard state.network.nodes.indices.contains(node) else { return .noSuchNode(node: node) }
            if state.network.nodes[node].owner == .player { return .alreadyOwned(node: node) }
            return state.network.attackable.contains(node) ? nil : .notLinked(node: node)
        case (.reinforce(let node), .map):
            guard state.network.nodes.indices.contains(node) else { return .noSuchNode(node: node) }
            let target = state.network.nodes[node]
            return target.owner == .player && target.contested ? nil : .notContested(node: node)
        case (.wait, .map):
            return nil
        case (.fight, .fight):
            return nil
        case (.takeReward(let choice, let replacing), .reward(_, let choices)):
            guard choices.indices.contains(choice) else { return .noSuchChoice(choice: choice) }
            guard state.deck.count >= state.storage else { return nil }
            guard let replacing else { return .storageFull }
            return state.deck.indices.contains(replacing) ? nil : .noSuchDeckCard(index: replacing)
        case (.skipReward, .reward):
            return nil
        case (.chooseUpgrade(let choice), .upgrade(_, let choices, _)):
            return choices.indices.contains(choice) ? nil : .noSuchChoice(choice: choice)
        default:
            return .wrongPhase
        }
    }

    // MARK: - Acting

    mutating func perform(_ action: ContractAction) {
        switch action {
        case .attack(let node):
            state.actionsLeft -= 1
            startFight(on: node)
        case .reinforce(let node):
            state.actionsLeft -= 1
            state.network.nodes[node].contested = false
            emit(.reinforced(node: node))
            finishAction()
        case .wait:
            state.actionsLeft -= 1
            emit(.waited)
            finishAction()
        case .fight(let fightAction):
            fight(fightAction)
        case .takeReward(let choice, let replacing):
            guard case .reward(_, let choices) = state.phase else { return }
            if state.deck.count >= state.storage, let replacing {
                emit(.cardDeleted(cardID: state.deck.remove(at: replacing)))
            }
            state.deck.append(choices[choice])
            emit(.cardAdded(cardID: choices[choice]))
            state.phase = .map
            finishAction()
        case .skipReward:
            emit(.rewardSkipped)
            state.phase = .map
            finishAction()
        case .chooseUpgrade(let choice):
            guard case .upgrade(let node, let choices, let reward) = state.phase else { return }
            applyUpgrade(choices[choice])
            state.network.nodes[node].upgradeTaken = true
            offerReward(node: node, choices: reward)
        }
    }

    /// After an action and everything it led to: the tick ends when the
    /// bandwidth is spent.
    mutating func finishAction() {
        guard state.outcome == nil, state.phase == .map, state.actionsLeft <= 0 else { return }
        endTick()
    }

    private mutating func applyUpgrade(_ upgrade: RigUpgrade) {
        switch upgrade.component {
        case .cpu: state.rig.cycles += upgrade.amount
        case .ram: state.rig.ram += upgrade.amount
        case .storage: state.storage += upgrade.amount
        case .chassis:
            state.rig.maxIntegrity += upgrade.amount
            state.integrity += upgrade.amount
        }
        emit(.upgradeChosen(upgrade))
    }

    mutating func offerReward(node: Int, choices: [String]) {
        state.phase = .reward(node: node, choices: choices)
        emit(.rewardOffered(cardIDs: choices))
    }

    /// `count` different cards from the reward pool.
    mutating func drawRewards() -> [String] {
        var pool = network.rewardPool
        state.rng.shuffle(&pool)
        return Array(pool.prefix(network.rewardChoices))
    }
}
