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
    var rules: RuleSet { state.rules }
    var tuning: Tuning { state.rules.tuning }
    var network: NetworkTuning { tuning.network }

    mutating func emit(_ event: ContractEvent) {
        events.append(event)
    }

    mutating func end(_ outcome: ContractOutcome) {
        state.phase = .over(outcome)
        emit(.contractEnded(outcome: outcome))
    }

    // MARK: - Alert and fog

    /// Changes Alert within 0 and its maximum. `isNoise` marks Alert the
    /// player made, which stops this tick's decay. ACTIVE, once reached,
    /// stays (addendum 01, §10, question 2). Without the `alert` flag,
    /// Alert does not move.
    mutating func changeAlert(by delta: Int, isNoise: Bool) {
        guard rules.isOn(.alert) else { return }
        let tuning = network.alert
        let total = min(tuning.max, max(0, state.alert + delta))
        if isNoise && delta > 0 { state.noiseThisTick += delta }
        guard total != state.alert else { return }
        emit(.alertChanged(by: total - state.alert, total: total))
        state.alert = total
        let next = state.alertState == .active ? .active : AlertState.of(total, tuning: tuning)
        if next != state.alertState {
            state.alertState = next
            emit(.alertStateChanged(next))
        }
    }

    /// Raises a node's visibility, never lowers it.
    mutating func reveal(_ node: Int, as visibility: Visibility) {
        guard state.network.nodes[node].visibility < visibility else { return }
        state.network.nodes[node].visibility = visibility
        emit(.nodeRevealed(node: node, visibility: visibility))
    }

    /// Footholds are SCANNED and the nodes linked to them DETECTED.
    mutating func revealAroundFootholds() {
        for node in state.network.nodes where node.isFoothold {
            reveal(node.index, as: .scanned)
            for neighbour in state.network.neighbours(of: node.index) {
                reveal(neighbour, as: .detected)
            }
        }
    }

    /// Whether the contract's objective is met now.
    var objectiveComplete: Bool {
        switch state.objective.win {
        case .captureRoot: state.network.nodes.contains { $0.type == .root && $0.owner == .player }
        case .exfiltrate: state.hasFile
        }
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
            guard state.network.nodes.indices.contains(node),
                state.network.nodes[node].visibility != .hidden
            else { return .noSuchNode(node: node) }
            if state.network.nodes[node].owner == .player { return .alreadyOwned(node: node) }
            return state.network.attackable.contains(node) ? nil : .notLinked(node: node)
        case (.reinforce(let node), .map):
            guard state.network.nodes.indices.contains(node) else { return .noSuchNode(node: node) }
            let target = state.network.nodes[node]
            return target.isFoothold && target.contested ? nil : .notContested(node: node)
        case (.scan, .map) where !rules.isOn(.scan):
            return .ruleOff(.scan)
        case (.jackOut, .map) where !rules.isOn(.jackOut):
            return .ruleOff(.jackOut)
        case (.scan(let node), .map):
            guard state.network.nodes.indices.contains(node) else { return .noSuchNode(node: node) }
            return state.network.nodes[node].visibility == .detected ? nil : .notDetected(node: node)
        case (.wait, .map), (.jackOut, .map), (.claim, .accessChoice), (.ghost, .accessChoice):
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
        case .scan(let node):
            state.actionsLeft -= 1
            emit(.scanned(node: node))
            changeAlert(by: network.alert.scan, isNoise: true)
            reveal(node, as: .scanned)
            finishAction()
        case .jackOut:
            emit(.jackedOut)
            if objectiveComplete && state.objective.win == .exfiltrate {
                let tier = PayoutTier.at(state.alertState)
                state.payout = tier
                emit(.payout(tier))
            }
            end(objectiveComplete ? .won : .jackedOut)
        case .claim:
            claim()
        case .ghost:
            ghost()
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
        var pool = network.rewardPool + (rules.isOn(.objectiveLoot) ? state.objective.extraRewards : [])
        state.rng.shuffle(&pool)
        return Array(pool.prefix(network.rewardChoices))
    }

    /// Chooses the objective's TARGET (addendum 01, §3.2): a node at least
    /// `minDistance` hops from ENTRY, not ROOT, from a PRNG of its own so
    /// that the contract's draws do not move. It takes the spec's type, its
    /// KERNEL is replaced by the TRANSFER, and the player knows where it is.
    mutating func markTarget(_ spec: TargetSpec, seed: UInt64) {
        var rng = Xoshiro256StarStar(seed: Seed.derive(seed, "objective"))
        guard let entry = state.network.nodes.firstIndex(where: { $0.type == .entry }) else { return }
        let distances = state.network.distances(from: entry)
        let candidates = state.network.nodes.indices.filter { index in
            let node = state.network.nodes[index]
            return node.type != .entry && node.type != .root && node.owner != .player
                && (distances[index] ?? 0) >= spec.minDistance
        }
        guard let node = rng.pick(candidates) else { return }
        state.targetNode = node
        state.fileMB = rng.nextInt(in: spec.fileMB.min...max(spec.fileMB.min, spec.fileMB.max))
        state.network.nodes[node].type = spec.nodeType
        state.network.nodes[node].machine.layers.removeAll { $0.kind == .kernel }
        emit(.targetMarked(node: node, fileMB: state.fileMB))
        reveal(node, as: .detected)
    }
}
