/// The crack prototype's pure reducer (addendum 03): a state and an action
/// in, a new state and the events out. All randomness comes from the PRNG in
/// the state, so a seed and an action list replay exactly.
public struct CrackEngine: Sendable {
    public let content: CrackContent

    public init(content: CrackContent) {
        self.content = content
    }

    /// Picks the code, shuffles the starter deck and starts turn 1.
    public func start(seed: UInt64) -> (CrackState, [CrackEvent]) {
        var rng = Xoshiro256StarStar(seed: Seed.derive(seed, "crack"))
        let code = pickCode(&rng)
        var deck = content.starterDeck.enumerated().map { CardInstance(uid: $0.offset, cardID: $0.element) }
        rng.shuffle(&deck)
        var state = CrackState(seed: seed, code: code, slots: content.codeLength, drawPile: deck, rng: rng)
        var events: [CrackEvent] = [.started(codeLength: content.codeLength, symbols: content.symbols)]
        startTurn(&state, &events)
        return (state, events)
    }

    public func apply(_ action: CrackAction, to state: CrackState) -> (CrackState, [CrackEvent]) {
        if let reason = rejection(of: action, in: state) {
            return (state, [.rejected(reason)])
        }
        var next = state
        var events: [CrackEvent] = []
        switch action {
        case .play(let handIndex, let slot):
            play(handIndex: handIndex, slot: slot, &next, &events)
        case .swap(let first, let second):
            next.energy -= content.costs.swap
            next.board.swapAt(first, second)
            events.append(.swapped(first, second))
        case .turn(let slot, let symbol):
            guard let current = next.board[slot] else { break }
            next.energy -= turnCost(from: current.symbol, to: symbol)
            next.board[slot]?.symbol = symbol
            events.append(.turned(slot: slot, from: current.symbol, to: symbol))
        case .drop(let handIndex):
            next.energy -= content.costs.drop
            let card = next.hand.remove(at: handIndex)
            next.discardPile.append(card)
            events.append(.dropped(card: label(card)))
        case .guess:
            guess(&next, &events)
        case .logout:
            next.outcome = .loggedOut
            events.append(.ended(.loggedOut))
        }
        return (next, events)
    }

    /// Why `action` cannot run in `state`, or nil when it can.
    public func rejection(of action: CrackAction, in state: CrackState) -> CrackRejectReason? {
        guard !state.isOver else { return .over }
        switch action {
        case .play(let handIndex, let slot):
            guard state.hand.indices.contains(handIndex) else { return .noSuchCard }
            guard state.board.indices.contains(slot) else { return .noSuchSlot }
            if kind(state.hand[handIndex]) == .probe && state.revealed[slot] != nil { return .alreadyKnown }
            return state.energy >= playCost(state.hand[handIndex]) ? nil : .noEnergy
        case .swap(let first, let second):
            guard state.board.indices.contains(first), state.board.indices.contains(second) else { return .noSuchSlot }
            guard first != second else { return .sameSlot }
            return state.energy >= content.costs.swap ? nil : .noEnergy
        case .turn(let slot, let symbol):
            guard state.board.indices.contains(slot) else { return .noSuchSlot }
            guard let current = state.board[slot], kind(current.card) == .dial else { return .notADial }
            guard content.symbols.contains(symbol) else { return .unknownSymbol }
            guard current.symbol != symbol else { return .alreadyShown }
            return state.energy >= turnCost(from: current.symbol, to: symbol) ? nil : .noEnergy
        case .drop(let handIndex):
            guard state.hand.indices.contains(handIndex) else { return .noSuchCard }
            return state.energy >= content.costs.drop ? nil : .noEnergy
        case .guess, .logout:
            return nil
        }
    }

    /// What a card shows in the hand: `A`, `DIAL-A`, `PROBE`.
    public func label(_ card: CardInstance) -> String {
        content.card(card.cardID)?.label ?? card.cardID
    }

    public func kind(_ card: CardInstance) -> CrackCardKind {
        content.card(card.cardID)?.kind ?? .symbol
    }

    /// The board as symbols, nil for an empty slot.
    public func boardSymbols(_ state: CrackState) -> [String?] {
        state.board.map { $0?.symbol }
    }

    /// What playing `card` costs: a probe has its own price.
    public func playCost(_ card: CardInstance) -> Int {
        kind(card) == .probe ? content.costs.probe : content.costs.place
    }

    /// Steps along the symbol list, the shorter way round, times the cost
    /// of a step.
    public func turnCost(from: String, to: String) -> Int {
        guard let start = content.symbols.firstIndex(of: from), let end = content.symbols.firstIndex(of: to) else {
            return 0
        }
        let forward = (end - start + content.symbols.count) % content.symbols.count
        return min(forward, content.symbols.count - forward) * content.costs.turn
    }

    private func play(handIndex: Int, slot: Int, _ state: inout CrackState, _ events: inout [CrackEvent]) {
        let card = state.hand[handIndex]
        state.energy -= playCost(card)
        state.hand.remove(at: handIndex)
        guard kind(card) != .probe else {
            state.revealed[slot] = state.code[slot]
            state.discardPile.append(card)
            events.append(.probed(slot: slot, symbol: state.code[slot]))
            return
        }
        let replaced = state.board[slot]
        if let replaced { state.discardPile.append(replaced.card) }
        let symbol = content.card(card.cardID)?.symbol ?? card.cardID
        state.board[slot] = CrackSlot(card: card, symbol: symbol)
        events.append(.placed(symbol: symbol, slot: slot, replaced: replaced?.symbol))
    }

    private func guess(_ state: inout CrackState, _ events: inout [CrackEvent]) {
        let symbols = boardSymbols(state)
        let guess = CrackGuess(symbols: symbols, feedback: CrackFeedback.score(guess: symbols, code: state.code))
        state.guesses.append(guess)
        state.alarm += content.alarm.perGuess
        events.append(.guessed(guess, alarm: state.alarm))
        if guess.feedback.hits == state.code.count {
            state.outcome = .cracked
            events.append(.ended(.cracked))
        } else if state.alarm >= content.alarm.max {
            state.outcome = .traced
            events.append(.ended(.traced))
        } else {
            startTurn(&state, &events)
        }
    }

    /// Refills energy and draws the hand back up to `handSize`. The hand is
    /// kept between turns; an empty draw pile takes the discard pile back.
    private func startTurn(_ state: inout CrackState, _ events: inout [CrackEvent]) {
        state.turn += 1
        state.energy = content.energy
        events.append(.turnStarted(turn: state.turn, energy: state.energy))
        var drawn: [String] = []
        while state.hand.count < content.handSize {
            if state.drawPile.isEmpty {
                guard !state.discardPile.isEmpty else { break }
                var pile = state.discardPile
                state.discardPile = []
                state.rng.shuffle(&pile)
                state.drawPile = pile
                if !drawn.isEmpty { events.append(.drew(symbols: drawn)) }
                drawn = []
                events.append(.reshuffled(count: pile.count))
            }
            let card = state.drawPile.removeFirst()
            state.hand.append(card)
            drawn.append(label(card))
        }
        if !drawn.isEmpty { events.append(.drew(symbols: drawn)) }
    }

    /// Each slot draws a symbol; a symbol already used `maxRepeats` times is
    /// left out of the draw for the later slots.
    private func pickCode(_ rng: inout Xoshiro256StarStar) -> [String] {
        var code: [String] = []
        for _ in 0..<content.codeLength {
            let allowed = content.symbols.filter { symbol in code.count { $0 == symbol } < content.maxRepeats }
            guard let symbol = rng.pick(allowed) else { break }
            code.append(symbol)
        }
        return code
    }
}
