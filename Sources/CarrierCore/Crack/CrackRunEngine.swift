/// The crack run's pure reducer: cracks in a row, a reward between each.
/// Crack `n` uses `Seed.derive(seed, "run/crack/n")` and its reward
/// `Seed.derive(seed, "run/reward/n")`.
public struct CrackRunEngine: Sendable {
    public let crack: CrackEngine

    public init(content: CrackContent) {
        crack = CrackEngine(content: content)
    }

    public var content: CrackContent { crack.content }

    public func start(seed: UInt64) -> (CrackRunState, [CrackRunEvent]) {
        var state = CrackRunState(seed: seed, deck: content.starterDeck, round: 0, phase: .lost)
        var events: [CrackRunEvent] = []
        startCrack(&state, &events)
        return (state, events)
    }

    public func apply(_ action: CrackRunAction, to state: CrackRunState) -> (CrackRunState, [CrackRunEvent]) {
        if let reason = rejection(of: action, in: state) {
            return (state, [.rejected(reason)])
        }
        var next = state
        var events: [CrackRunEvent] = []
        switch (action, state.phase) {
        case (.crack(let action), .cracking(let crackState)):
            let (after, crackEvents) = crack.apply(action, to: crackState)
            next.phase = .cracking(after)
            events += crackEvents.map(CrackRunEvent.crack)
            if after.isOver { endCrack(after, &next, &events) }
        case (.take(let index), .reward(let cards, _)):
            next.deck.append(cards[index])
            events.append(.took(cards[index]))
            nextRound(&next, &events)
        case (.remove(let index), .reward):
            let card = next.deck.remove(at: index)
            events.append(.removed(card))
            nextRound(&next, &events)
        case (.skip, .reward):
            events.append(.skipped)
            nextRound(&next, &events)
        default:
            break
        }
        return (next, events)
    }

    public func rejection(of action: CrackRunAction, in state: CrackRunState) -> CrackRunRejectReason? {
        guard !state.isOver else { return .over }
        switch (action, state.phase) {
        case (.crack, .cracking):
            return nil
        case (.crack, _):
            return .notInACrack
        case (_, .cracking), (_, .won), (_, .lost):
            return .notAtAReward
        case (.take(let index), .reward(let cards, _)):
            guard cards.indices.contains(index) else { return .noSuchChoice }
            return state.deck.count < content.run.deckLimit ? nil : .deckFull
        case (.remove(let index), .reward(_, let next)):
            guard state.deck.indices.contains(index) else { return .noSuchChoice }
            let length = content.server(next)?.codeLength ?? 0
            return state.deck.count > content.handSize + length ? nil : .deckTooSmall
        case (.skip, .reward):
            return nil
        }
    }

    /// The server of round `round`, if the run has one.
    public func server(round: Int) -> CrackServer? {
        guard content.run.servers.indices.contains(round) else { return nil }
        return content.server(content.run.servers[round])
    }

    private func startCrack(_ state: inout CrackRunState, _ events: inout [CrackRunEvent]) {
        guard let server = server(round: state.round) else {
            state.phase = .won
            events.append(.won(servers: state.round))
            return
        }
        let seed = Seed.derive(state.seed, "run/crack/\(state.round)")
        let (crackState, crackEvents) = crack.start(seed: seed, server: server, deck: state.deck)
        state.phase = .cracking(crackState)
        events += crackEvents.map(CrackRunEvent.crack)
    }

    private func endCrack(_ crackState: CrackState, _ state: inout CrackRunState, _ events: inout [CrackRunEvent]) {
        guard crackState.outcome == .cracked else {
            state.phase = .lost
            events.append(.lost(round: state.round))
            return
        }
        guard let next = server(round: state.round + 1) else {
            state.round += 1
            state.phase = .won
            events.append(.won(servers: state.round))
            return
        }
        var rng = Xoshiro256StarStar(seed: Seed.derive(state.seed, "run/reward/\(state.round)"))
        var pool: [String] = []
        for card in content.run.rewardPool where !pool.contains(card) {
            pool.append(card)
        }
        rng.shuffle(&pool)
        let cards = Array(pool.prefix(content.run.rewardChoices))
        state.phase = .reward(cards: cards, next: next.id)
        events.append(.rewardOffered(cards: cards, next: next.id))
    }

    private func nextRound(_ state: inout CrackRunState, _ events: inout [CrackRunEvent]) {
        state.round += 1
        startCrack(&state, &events)
    }
}
