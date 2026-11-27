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
            startingProxy: proxy
        )
        emit(.fightStarting(node: node, startingProxy: proxy))
        let (game, fightEvents) = engine.fightEngine.startFight(setup)
        events += fightEvents.map(ContractEvent.fight)
        state.phase = .fight(node: node, state: game.fight, deck: setup.deck)
        if game.fight.isOver {
            resolveFight(node: node, fight: game.fight, deck: setup.deck)
        }
    }

    mutating func fight(_ action: Action) {
        guard case .fight(let node, let fight, let deck) = state.phase else { return }
        let (next, fightEvents) = engine.fightEngine.apply(action, to: GameState(seed: state.seed, fight: fight))
        events += fightEvents.map(ContractEvent.fight)
        state.phase = .fight(node: node, state: next.fight, deck: deck)
        if next.fight.isOver {
            resolveFight(node: node, fight: next.fight, deck: deck)
        }
    }

    /// Carries a finished fight back into the contract. Integrity and Trace
    /// come back whatever happened; PAYLOAD that was played is gone from the
    /// deck; malware the ICE injected stays behind.
    private mutating func resolveFight(node: Int, fight: FightState, deck: [String]) {
        state.integrity = fight.integrity
        state.trace = fight.trace
        let spent = Set(fight.consumedCards.map(\.uid))
        if !spent.isEmpty {
            emit(.cardsSpent(cardIDs: fight.consumedCards.map(\.cardID)))
        }
        // A card's uid is its position in the deck the fight started with.
        state.deck = deck.enumerated().filter { !spent.contains($0.offset) }.map(\.element)

        switch fight.outcome {
        case .captured:
            capture(node: node, machine: fight.machine)
        case .loggedOut, nil:
            emit(.nodeLeft(node: node))
            state.phase = .map
            finishAction()
        case .flatlined:
            end(.flatlined)
        case .traced:
            end(.traced)
        }
    }

    private mutating func capture(node: Int, machine: Machine) {
        state.network.nodes[node].owner = .player
        state.network.nodes[node].contested = false
        state.network.nodes[node].machine = machine
        emit(.nodeCaptured(node: node))
        let captured = state.network.nodes[node]
        if captured.type == .root {
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
