/// The pure reducer (kickoff §8): an action and a state in, a new state and
/// the events out. No I/O, no clock, and every random draw comes from the
/// PRNG inside the state, so a seed and an action log replay exactly.
public struct Engine: Sendable {
    public let content: ContentPack

    public init(content: ContentPack) {
        self.content = content
    }

    /// Shuffles the deck, starts the ICE and runs the first turn's start.
    public func startFight(_ setup: FightSetup) -> (GameState, [Event]) {
        var rng = Xoshiro256StarStar(seed: Seed.derive(setup.seed, "fight"))
        var deck = setup.deck.enumerated().map { CardInstance(uid: $0.offset, cardID: $0.element) }
        rng.shuffle(&deck)
        let fight = FightState(
            machine: setup.machine,
            ice: setup.machine.ice.map { ICEInstance(iceID: $0) },
            drawPile: deck,
            rig: setup.rig,
            cycles: 0,
            integrity: setup.integrity,
            trace: setup.trace,
            turn: 0,
            rng: rng,
            nextUID: deck.count,
            transfer: setup.transfer
        )
        var resolver = FightResolver(fight: fight, content: content)
        resolver.emit(.fightStarted(hostname: setup.machine.hostname, ice: setup.machine.ice))
        // Trace and Integrity come in from the contract (M3); a fight that
        // starts already lost ends before its first turn.
        resolver.checkForEnd()
        if !resolver.fight.isOver {
            resolver.startTurn(startingProxy: setup.startingProxy)
        }
        return (GameState(seed: setup.seed, fight: resolver.fight), resolver.events)
    }

    public func apply(_ action: Action, to state: GameState) -> (GameState, [Event]) {
        var resolver = FightResolver(fight: state.fight, content: content)
        guard !state.fight.isOver else {
            return (state, [.actionRejected(reason: .fightOver)])
        }
        switch action {
        case .play(let handIndex):
            if let reason = resolver.rejection(forPlaying: handIndex) {
                return (state, [.actionRejected(reason: reason)])
            }
            resolver.play(handIndex: handIndex)
        case .endTurn:
            resolver.endTurn()
        case .logout:
            resolver.logout()
        }
        var next = state
        next.fight = resolver.fight
        return (next, resolver.events)
    }

    /// Why the card at `handIndex` cannot be played now, or nil when it can.
    /// A frontend uses it to mark cards; a bot uses it to choose.
    public func rejection(forPlaying handIndex: Int, in fight: FightState) -> RejectReason? {
        guard !fight.isOver else { return .fightOver }
        return FightResolver(fight: fight, content: content).rejection(forPlaying: handIndex)
    }

    /// What each ICE program will do at the end of this turn, with the
    /// numbers the player will actually feel: the CPU tier's attack bonus,
    /// the modem's Trace multiplier and any CLOAK reduction applied.
    public func telegraph(_ fight: FightState) -> [ICETelegraph] {
        let resolver = FightResolver(fight: fight, content: content)
        return fight.ice.map { program in
            ICETelegraph(iceID: program.iceID, intents: resolver.upcomingIntents(for: program))
        }
    }
}

/// One ICE program's telegraphed intents for the coming end of turn.
public struct ICETelegraph: Sendable, Equatable {
    public let iceID: String
    public let intents: [Intent]

    public init(iceID: String, intents: [Intent]) {
        self.iceID = iceID
        self.intents = intents
    }
}
