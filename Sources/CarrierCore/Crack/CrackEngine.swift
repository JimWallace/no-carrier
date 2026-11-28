/// The crack prototype's pure reducer (addendum 03): a state and an action
/// in, a new state and the events out. All randomness comes from the PRNG in
/// the state, so a seed and an action list replay exactly.
public struct CrackEngine: Sendable {
    public let content: CrackContent

    public init(content: CrackContent) {
        self.content = content
    }

    /// Picks the code for `server`, shuffles `deck` (the starter deck when
    /// nil) and starts turn 1.
    public func start(seed: UInt64, server: CrackServer, deck: [String]? = nil) -> (CrackState, [CrackEvent]) {
        var rng = Xoshiro256StarStar(seed: Seed.derive(seed, "crack"))
        let code = pickCode(for: server, &rng)
        let cards = deck ?? content.starterDeck
        var instances = cards.enumerated().map { CardInstance(uid: $0.offset, cardID: $0.element) }
        rng.shuffle(&instances)
        var state = CrackState(seed: seed, server: server, code: code, drawPile: instances, rng: rng)
        var events: [CrackEvent] = [
            .started(server: server.name, codeLength: server.codeLength, symbols: server.symbols)
        ]
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
        case .use(let handIndex):
            use(handIndex: handIndex, &next, &events)
        case .swap(let first, let second):
            next.energy -= content.costs.swap
            next.board.swapAt(first, second)
            next.locked.swapAt(first, second)
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
        case .hold:
            next.alarm += content.alarm.hold
            events.append(.held(alarm: next.alarm))
            endTurn(&next, &events)
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
            let card = state.hand[handIndex]
            guard kind(card).needsSlot else { return .needsNoSlot }
            guard state.board.indices.contains(slot) else { return .noSuchSlot }
            switch kind(card) {
            case .probe where state.revealed[slot] != nil:
                return .alreadyKnown
            case .sniff, .count, .lock:
                if state.board[slot] == nil { return .emptySlot }
            default:
                break
            }
            return state.energy >= playCost(card) ? nil : .noEnergy
        case .use(let handIndex):
            guard state.hand.indices.contains(handIndex) else { return .noSuchCard }
            let card = state.hand[handIndex]
            guard !kind(card).needsSlot else { return .needsSlot }
            return state.energy >= playCost(card) ? nil : .noEnergy
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
        case .guess, .hold, .logout:
            return nil
        }
    }

    /// Why hand card `index` cannot be played now on any slot, or nil when
    /// it can be played somewhere. A frontend marks cards with it.
    public func refusal(forCard index: Int, in state: CrackState) -> CrackRejectReason? {
        guard state.hand.indices.contains(index) else { return .noSuchCard }
        guard kind(state.hand[index]).needsSlot else { return rejection(of: .use(handIndex: index), in: state) }
        var first: CrackRejectReason?
        for slot in state.board.indices {
            guard let reason = rejection(of: .play(handIndex: index, slot: slot), in: state) else { return nil }
            first = first ?? reason
        }
        return first
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

    /// What playing `card` costs: its own cost, else the price of its kind.
    public func playCost(_ card: CardInstance) -> Int {
        cost(of: content.card(card.cardID))
    }

    /// What playing a card of this definition costs.
    public func cost(of definition: CrackCard?) -> Int {
        if let cost = definition?.cost { return cost }
        return definition?.kind == .probe ? content.costs.probe : content.costs.place
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

    /// What the next guess will add to the alarm, with DEBUG and SPOOF.
    public func nextGuessCost(_ state: CrackState) -> Int {
        let base = alarmCost(ofGuess: state.guesses.count, server: state.server) + (state.debugAlarm ?? 0)
        return base * (state.spoofPercent ?? 100) / 100
    }

    /// What guess number `index` (from 0) adds to the alarm.
    public func alarmCost(ofGuess index: Int, server: CrackServer) -> Int {
        server.alarmPerGuess + server.escalation * index
    }

    /// Turns until each interference program next acts: 0 means at the end
    /// of this turn.
    public func turnsUntil(_ program: CrackInterference, in state: CrackState) -> Int {
        guard program.every > 0 else { return 0 }
        return (program.every - state.turn % program.every) % program.every
    }

    private func play(handIndex: Int, slot: Int, _ state: inout CrackState, _ events: inout [CrackEvent]) {
        let card = state.hand[handIndex]
        state.energy -= playCost(card)
        state.hand.remove(at: handIndex)
        let shown = state.board[slot]?.symbol ?? ""
        switch kind(card) {
        case .symbol, .dial:
            let replaced = state.board[slot]
            if let replaced { state.discardPile.append(replaced.card) }
            let symbol = content.card(card.cardID)?.symbol ?? card.cardID
            state.board[slot] = CrackSlot(card: card, symbol: symbol)
            state.locked[slot] = false
            events.append(.placed(symbol: symbol, slot: slot, replaced: replaced?.symbol))
            return
        case .probe:
            state.revealed[slot] = state.code[slot]
            events.append(.probed(slot: slot, symbol: state.code[slot]))
        case .sniff:
            learn(.contains(symbol: shown, state.code.contains(shown)), &state, &events)
        case .count:
            learn(.count(symbol: shown, state.code.count { $0 == shown }), &state, &events)
        case .lock:
            state.locked[slot] = true
            events.append(.lockedSlot(slot))
        case .debug, .spoof, .shift, .overclock:
            break
        }
        state.discardPile.append(card)
    }

    private func use(handIndex: Int, _ state: inout CrackState, _ events: inout [CrackEvent]) {
        let card = state.hand[handIndex]
        let definition = content.card(card.cardID)
        state.energy -= playCost(card)
        state.hand.remove(at: handIndex)
        switch kind(card) {
        case .debug:
            state.debugAlarm = definition?.amount ?? 0
            events.append(.debugArmed)
        case .spoof:
            let percent = definition?.amount ?? 100
            state.spoofPercent = percent
            events.append(.spoofArmed(percent: percent))
        case .shift:
            if let last = state.board.popLast() { state.board.insert(last, at: 0) }
            if let last = state.locked.popLast() { state.locked.insert(last, at: 0) }
            events.append(.shifted)
        case .overclock:
            state.energy += definition?.amount ?? 0
            state.energyDebt += definition?.penalty ?? 0
            events.append(.overclocked(energy: state.energy))
        case .symbol, .dial, .probe, .sniff, .count, .lock:
            break
        }
        state.discardPile.append(card)
    }

    private func learn(_ fact: CrackFact, _ state: inout CrackState, _ events: inout [CrackEvent]) {
        state.facts.append(fact)
        events.append(.learned(fact))
    }

    private func guess(_ state: inout CrackState, _ events: inout [CrackEvent]) {
        let symbols = boardSymbols(state)
        let style = state.debugAlarm == nil ? state.server.feedback : .slots
        let feedback = CrackFeedback.score(guess: symbols, code: state.code, style: style)
        let guess = CrackGuess(symbols: symbols, feedback: feedback, style: style)
        state.alarm += nextGuessCost(state)
        state.debugAlarm = nil
        state.spoofPercent = nil
        state.guesses.append(guess)
        events.append(.guessed(guess, alarm: state.alarm))
        if guess.feedback.hits == state.code.count {
            state.outcome = .cracked
            events.append(.ended(.cracked))
            return
        }
        endTurn(&state, &events)
    }

    /// After a guess or a HOLD: the line drops at a full alarm; otherwise
    /// the server acts and the next turn starts.
    private func endTurn(_ state: inout CrackState, _ events: inout [CrackEvent]) {
        if state.alarm >= content.alarm.max {
            state.outcome = .traced
            events.append(.ended(.traced))
            return
        }
        interfere(&state, &events)
        startTurn(&state, &events)
    }

    /// Each program whose turn it is acts, in the order the server lists
    /// them.
    private func interfere(_ state: inout CrackState, _ events: inout [CrackEvent]) {
        for program in state.server.interference where turnsUntil(program, in: state) == 0 {
            switch program.kind {
            case .scramble:
                let free = state.board.indices.filter { !state.locked[$0] }
                guard free.count > 1 else { continue }
                let first = state.rng.nextInt(below: free.count)
                let second = (first + 1 + state.rng.nextInt(below: free.count - 1)) % free.count
                let (low, high) = (min(free[first], free[second]), max(free[first], free[second]))
                state.board.swapAt(low, high)
                events.append(.scrambled(low, high))
            case .rotate:
                guard let last = state.code.popLast() else { continue }
                state.code.insert(last, at: 0)
                if let known = state.revealed.popLast() { state.revealed.insert(known, at: 0) }
                state.rotations.append(state.guesses.count)
                events.append(.rotated)
            }
        }
    }

    /// Refills energy, less any OVERCLOCK debt, and draws the hand back up
    /// to `handSize`. The hand is kept between turns; an empty draw pile
    /// takes the discard pile back.
    private func startTurn(_ state: inout CrackState, _ events: inout [CrackEvent]) {
        state.turn += 1
        state.energy = max(0, content.energy - state.energyDebt)
        state.energyDebt = 0
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
    private func pickCode(for server: CrackServer, _ rng: inout Xoshiro256StarStar) -> [String] {
        var code: [String] = []
        for _ in 0..<server.codeLength {
            let allowed = server.symbols.filter { symbol in code.count { $0 == symbol } < server.maxRepeats }
            guard let symbol = rng.pick(allowed) else { break }
            code.append(symbol)
        }
        return code
    }
}
