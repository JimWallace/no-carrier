extension ContractResolver {
    mutating func startFight(on node: Int) {
        state.fightsStarted += 1
        let proxy = engine.relayProxy(state)
        let setup = FightSetup(
            seed: Seed.derive(state.seed, "fight/\(state.fightsStarted)"),
            machine: state.network.nodes[node].machine,
            deck: state.deck,
            rig: state.rig,
            integrity: state.integrity,
            trace: state.trace,
            startingProxy: proxy,
            transfer: node == state.targetNode && !state.hasFile
                ? TransferProgress(totalMB: state.fileMB, rateMB: state.network.nodes[node].machine.modem.transferMB)
                : nil
        )
        state.claimChosen = false
        state.lastPlayTurn = nil
        emit(.fightStarting(node: node, startingProxy: proxy))
        let (game, fightEvents) = engine.fightEngine.startFight(setup, rules: rules)
        absorb(fightEvents, node: node, before: game.fight)
        state.phase = .fight(node: node, state: game.fight, deck: setup.deck)
        afterFightStep(node: node, fight: game.fight, deck: setup.deck)
    }

    mutating func fight(_ action: Action) {
        guard case .fight(let node, let fight, let deck) = state.phase else { return }
        let fightSeed = Seed.derive(state.seed, "fight/\(state.fightsStarted)")
        let (next, fightEvents) = engine.fightEngine.apply(
            action, to: GameState(seed: fightSeed, fight: fight, rules: rules))
        absorb(fightEvents, node: node, before: fight)
        state.phase = .fight(node: node, state: next.fight, deck: deck)
        afterFightStep(node: node, fight: next.fight, deck: deck)
    }

    /// Passes the fight's events on, and reads the two that matter to the
    /// network: each card played makes its noise, and PROBE scans the node.
    /// GHOST.DMN, running in `before`, silences the first card of a turn.
    private mutating func absorb(_ fightEvents: [Event], node: Int, before: FightState) {
        let quiet = before.daemons.contains { daemon in
            content.card(daemon.cardID)?.daemon?.passives.contains(.quietFirstCard) ?? false
        }
        for event in fightEvents {
            emit(.fight(event))
            switch event {
            case .cardPlayed(let cardID, let spent):
                let firstThisTurn = state.lastPlayTurn != before.turn
                state.lastPlayTurn = before.turn
                if let card = content.card(cardID), !(quiet && firstThisTurn) {
                    let noise = card.noise(cycles: spent)
                    if noise != 0 { changeAlert(by: noise, isNoise: noise > 0) }
                }
            case .weaknessRevealed:
                reveal(node, as: .scanned)
            default:
                break
            }
        }
    }

    /// After each fight step: offer CLAIM or GHOST once AUTH falls, when the
    /// objective allows it; else end the fight when it is over.
    private mutating func afterFightStep(node: Int, fight: FightState, deck: [String]) {
        let outerBreached = fight.machine.layers.allSatisfy { $0.kind == .kernel || $0.isBreached }
        let canGhost =
            rules.isOn(.ghost) && !state.claimChosen && !state.network.nodes[node].accessed && fight.transfer == nil
        if canGhost && outerBreached && (fight.outcome == nil || fight.outcome == .captured) {
            state.phase = .accessChoice(node: node, state: fight, deck: deck)
            emit(.accessChoiceOffered(node: node))
            return
        }
        if fight.isOver {
            resolveFight(node: node, fight: fight, deck: deck)
        }
    }

    mutating func claim() {
        guard case .accessChoice(let node, let fight, let deck) = state.phase else { return }
        state.claimChosen = true
        state.phase = .fight(node: node, state: fight, deck: deck)
        if fight.isOver {
            resolveFight(node: node, fight: fight, deck: deck)
        }
    }

    /// GHOST: take access and leave. The fight's costs come back with the
    /// player, as after a LOGOUT, but the node is not theirs.
    mutating func ghost() {
        guard case .accessChoice(let node, let fight, let deck) = state.phase else { return }
        carryBack(fight: fight, deck: deck)
        if fight.trace >= tuning.trace.max {
            end(.traced)
            return
        }
        state.network.nodes[node].accessed = true
        state.network.nodes[node].contested = false
        emit(.accessGained(node: node))
        changeAlert(by: network.alert.access, isNoise: true)
        revealAroundFootholds()
        state.phase = .map
        finishAction()
    }

    /// Carries a finished fight back into the contract. Integrity and Trace
    /// come back whatever happened; PAYLOAD that was played is gone from the
    /// deck; malware the ICE injected stays behind.
    private mutating func resolveFight(node: Int, fight: FightState, deck: [String]) {
        carryBack(fight: fight, deck: deck)

        // Kickoff §3, step 6: Trace is checked first, so a node captured
        // with Trace full is NO CARRIER, ROOT included.
        if fight.trace >= tuning.trace.max {
            end(.traced)
            return
        }
        switch fight.outcome {
        case .captured:
            capture(node: node)
        case .loggedOut, nil:
            if let transfer = fight.transfer, transfer.isComplete, !state.hasFile {
                state.hasFile = true
                emit(.fileCopied(fileMB: transfer.totalMB))
            }
            emit(.nodeLeft(node: node))
            state.phase = .map
            finishAction()
        case .flatlined:
            end(.flatlined)
        case .traced:
            end(.traced)
        }
    }

    private mutating func carryBack(fight: FightState, deck: [String]) {
        state.integrity = fight.integrity
        state.trace = fight.trace
        let spent = Set(fight.consumedCards.map(\.uid))
        if !spent.isEmpty {
            emit(.cardsSpent(cardIDs: fight.consumedCards.map(\.cardID)))
        }
        // A card's uid is its position in the deck the fight started with.
        state.deck = deck.enumerated().filter { !spent.contains($0.offset) }.map(\.element)
    }

    /// The node keeps its machine as it was before the fight, so HARDEN
    /// inside the fight does not make it stronger if the sysop takes it back.
    private mutating func capture(node: Int) {
        state.network.nodes[node].owner = .player
        state.network.nodes[node].contested = false
        state.network.nodes[node].accessed = false
        emit(.nodeCaptured(node: node))
        changeAlert(by: network.alert.capture, isNoise: true)
        revealAroundFootholds()
        let captured = state.network.nodes[node]
        if objectiveComplete {
            end(.won)
            return
        }
        let reward = drawRewards()
        if captured.type == .data && !captured.upgradeTaken {
            state.phase = .upgrade(node: node, choices: network.dataUpgrades, reward: reward)
            emit(.upgradeOffered(choices: network.dataUpgrades))
        } else {
            offerReward(node: node, choices: reward)
        }
    }
}
