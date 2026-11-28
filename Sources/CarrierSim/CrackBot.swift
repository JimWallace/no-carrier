public import CarrierCore

/// A careful crack player (addendum 03). It keeps every code that agrees
/// with the feedback and the probes so far, and each turn moves the board
/// toward the one of them that needs the fewest changes. It plays a probe
/// on the slot it knows least about. With energy to spare, it drops cards the code it aims for does not need.
///
/// It stands in for an attentive human, not a perfect solver: it never
/// guesses a code it knows is wrong unless energy runs out first.
public struct CrackBot: Sendable {
    public let engine: CrackEngine
    /// Codes that agree with everything seen so far, in a fixed order.
    public private(set) var candidates: [[String]]
    private var guessesSeen = 0
    private var actionsThisTurn = 0
    private var turnSeen = 0

    public let server: CrackServer
    private var rotationsSeen = 0
    private var factsSeen = 0

    public init(engine: CrackEngine, server: CrackServer) {
        self.engine = engine
        self.server = server
        candidates = Self.allCodes(server)
    }

    /// The next action for `state`.
    public mutating func next(_ state: CrackState) -> CrackAction {
        learn(state)
        if state.turn != turnSeen {
            turnSeen = state.turn
            actionsThisTurn = 0
        }
        actionsThisTurn += 1
        // A content file with free actions could loop for ever.
        guard actionsThisTurn <= 20 else { return .guess }
        let fresh = actionsThisTurn == 1
        if let overclock = useFirst(.overclock, in: state, when: fresh) { return overclock }
        let hidden = server.feedback != .slots && candidates.count > 2
        if state.debugAlarm == nil, let debug = useFirst(.debug, in: state, when: hidden) { return debug }
        let costly = engine.nextGuessCost(state) >= engine.content.alarm.max / 10
        if state.spoofPercent == nil, let spoof = useFirst(.spoof, in: state, when: costly && candidates.count > 1) {
            return spoof
        }
        if let probe = probe(state) { return probe }
        if let sniff = sniffOrCount(state) { return sniff }
        guard let target = target(state) else { return finish(state) }
        if let shift = shift(toward: target, in: state) { return shift }
        return step(toward: target, in: state) ?? drop(keeping: target, in: state) ?? finish(state)
    }

    /// The end of a turn: LOCK a slot on a scrambling server, DEBUG or
    /// SPOOF the guess, then guess, or HOLD when the guess would repeat the
    /// last one and teach nothing.
    private func finish(_ state: CrackState) -> CrackAction {
        let board = engine.boardSymbols(state)
        if server.interference.contains(where: { $0.kind == .scramble }),
            let card = state.hand.firstIndex(where: { engine.kind($0) == .lock }),
            let slot = board.indices.first(where: { board[$0] != nil && !state.locked[$0] }),
            engine.rejection(of: .play(handIndex: card, slot: slot), in: state) == nil
        {
            return .play(handIndex: card, slot: slot)
        }
        // The same board again teaches nothing, unless the code rotated
        // since: then it is read against a new code.
        let rotatedSince = state.rotations.last == state.guesses.count
        if let last = state.guesses.last, last.symbols == board, !rotatedSince { return .hold }
        return .guess
    }

    /// `.use` on the first card of `kind` in hand, if `condition` holds and
    /// it is affordable.
    private func useFirst(_ kind: CrackCardKind, in state: CrackState, when condition: Bool) -> CrackAction? {
        guard condition, let index = state.hand.firstIndex(where: { engine.kind($0) == kind }) else { return nil }
        let action = CrackAction.use(handIndex: index)
        return engine.rejection(of: action, in: state) == nil ? action : nil
    }

    /// A SNIFF or COUNT on the board slot whose symbol splits the
    /// candidates most evenly.
    private func sniffOrCount(_ state: CrackState) -> CrackAction? {
        guard candidates.count > 1,
            let card = state.hand.firstIndex(where: { [.sniff, .count].contains(engine.kind($0)) })
        else { return nil }
        let isCount = engine.kind(state.hand[card]) == .count
        var best: (slot: Int, score: Int)?
        var asked: [String] = []
        for (slot, symbol) in engine.boardSymbols(state).enumerated() {
            guard let symbol, !asked.contains(symbol) else { continue }
            asked.append(symbol)
            let fact: (([String]) -> Int) =
                isCount ? { code in code.count { $0 == symbol } } : { $0.contains(symbol) ? 1 : 0 }
            var sizes: [Int] = []
            var values: [Int] = []
            for code in candidates {
                let value = fact(code)
                if let index = values.firstIndex(of: value) {
                    sizes[index] += 1
                } else {
                    values.append(value)
                    sizes.append(1)
                }
            }
            // The largest group left after the answer: smaller is better.
            let worst = sizes.max() ?? candidates.count
            if worst < candidates.count && worst < (best?.score ?? Int.max) { best = (slot, worst) }
        }
        guard let best else { return nil }
        let action = CrackAction.play(handIndex: card, slot: best.slot)
        return engine.rejection(of: action, in: state) == nil ? action : nil
    }

    /// SHIFT when moving the whole board one slot right fixes at least two
    /// more slots than it breaks.
    private func shift(toward target: [String], in state: CrackState) -> CrackAction? {
        let board = engine.boardSymbols(state)
        let shifted = [board[board.count - 1]] + board.dropLast()
        let now = target.indices.count { board[$0] == target[$0] }
        let after = target.indices.count { shifted[$0] == target[$0] }
        guard after >= now + 2 else { return nil }
        return useFirst(.shift, in: state, when: true)
    }

    /// With energy left and nothing to fix, drops a card the target does
    /// not need, so the next turn draws something new. Probes and dials are
    /// kept.
    private func drop(keeping target: [String], in state: CrackState) -> CrackAction? {
        var needed = target
        for slot in state.board.compactMap({ $0?.symbol }) {
            if let index = needed.firstIndex(of: slot) { needed.remove(at: index) }
        }
        // A card this server gives no use for clogs the hand: drop it first.
        let scrambles = server.interference.contains { $0.kind == .scramble }
        let rotates = server.interference.contains { $0.kind == .rotate }
        for (index, card) in state.hand.enumerated() {
            let kind = engine.kind(card)
            let useless =
                (kind == .lock && !scrambles) || (kind == .shift && !rotates)
                || (kind == .debug && server.feedback == .slots)
                || ([.probe, .sniff, .count, .debug, .spoof].contains(kind) && candidates.count <= 1)
            let action = CrackAction.drop(handIndex: index)
            if useless && engine.rejection(of: action, in: state) == nil { return action }
        }
        for (index, card) in state.hand.enumerated() where engine.kind(card) == .symbol {
            let symbol = engine.content.card(card.cardID)?.symbol ?? ""
            if let use = needed.firstIndex(of: symbol) {
                needed.remove(at: use)
                continue
            }
            let action = CrackAction.drop(handIndex: index)
            if engine.rejection(of: action, in: state) == nil { return action }
        }
        return nil
    }

    /// Drops every candidate that a new guess or a probe rules out. Each
    /// guess is read against the code as it was then: a ROTATE after it
    /// moves every candidate along with the code.
    private mutating func learn(_ state: CrackState) {
        // A ROTATE is stamped with the guesses made before it; with HOLD it
        // can come before the first guess or between two guesses.
        while true {
            while rotationsSeen < state.rotations.count && state.rotations[rotationsSeen] == guessesSeen {
                candidates = candidates.map { [$0[$0.count - 1]] + $0.dropLast() }
                rotationsSeen += 1
            }
            guard guessesSeen < state.guesses.count else { break }
            let guess = state.guesses[guessesSeen]
            candidates = candidates.filter {
                CrackFeedback.score(guess: guess.symbols, code: $0, style: guess.style) == guess.feedback
            }
            guessesSeen += 1
        }
        let facts = state.facts.dropFirst(factsSeen)
        factsSeen = state.facts.count
        if !facts.isEmpty {
            candidates = candidates.filter { code in facts.allSatisfy { $0.holds(for: code) } }
        }
        let revealed = state.revealed
        candidates = candidates.filter { code in
            revealed.enumerated().allSatisfy { $0.element == nil || code[$0.offset] == $0.element }
        }
    }

    /// A probe on the unrevealed slot whose symbol the candidates disagree
    /// on most, when the hand has one and the code is not yet known.
    private func probe(_ state: CrackState) -> CrackAction? {
        guard candidates.count > 1,
            let index = state.hand.firstIndex(where: { engine.kind($0) == .probe }),
            state.energy >= engine.playCost(state.hand[index])
        else { return nil }
        var best: (slot: Int, spread: Int)?
        for slot in state.board.indices where state.revealed[slot] == nil {
            var seen: [String] = []
            for code in candidates where !seen.contains(code[slot]) {
                seen.append(code[slot])
            }
            if seen.count > 1 && seen.count > (best?.spread ?? 0) {
                best = (slot, seen.count)
            }
        }
        return best.map { .play(handIndex: index, slot: $0.slot) }
    }

    /// The candidate that differs from the board in the fewest slots.
    private func target(_ state: CrackState) -> [String]? {
        let board = engine.boardSymbols(state)
        var best: (code: [String], misses: Int)?
        for code in candidates {
            let misses = code.indices.count { board[$0] != code[$0] }
            if misses < (best?.misses ?? Int.max) {
                best = (code, misses)
            }
        }
        return best?.code
    }

    /// The cheapest affordable action that fixes a slot, best first: a swap
    /// that fixes two, a dial turn, a card from the hand, a swap that fixes
    /// one.
    private func step(toward target: [String], in state: CrackState) -> CrackAction? {
        let board = engine.boardSymbols(state)
        let wrong = target.indices.filter { board[$0] != target[$0] }
        var options: [CrackAction] = []
        for first in wrong {
            for second in wrong where second > first && board[first] == target[second] && board[second] == target[first]
            {
                options.append(.swap(first, second))
            }
        }
        for slot in wrong where state.board[slot].map({ engine.kind($0.card) == .dial }) == true {
            let cost = engine.turnCost(from: board[slot] ?? "", to: target[slot])
            if cost <= engine.content.costs.place {
                options.append(.turn(slot: slot, symbol: target[slot]))
            }
        }
        for slot in wrong {
            let card = state.hand.firstIndex {
                engine.kind($0) != .probe && engine.content.card($0.cardID)?.symbol == target[slot]
            }
            if let card { options.append(.play(handIndex: card, slot: slot)) }
        }
        for slot in wrong {
            for other in board.indices
            where other != slot && board[other] == target[slot] && board[other] != target[other] {
                options.append(.swap(slot, other))
            }
        }
        for slot in wrong where state.board[slot].map({ engine.kind($0.card) == .dial }) == true {
            options.append(.turn(slot: slot, symbol: target[slot]))
        }
        // No card for a slot: a dial from the hand goes there, to be turned
        // next.
        if let dial = state.hand.firstIndex(where: { engine.kind($0) == .dial }),
            let slot = wrong.first(where: { state.board[$0].map { engine.kind($0.card) != .dial } ?? true })
        {
            options.append(.play(handIndex: dial, slot: slot))
        }
        return options.first { engine.rejection(of: $0, in: state) == nil }
    }

    /// Every code the server can make, in order.
    static func allCodes(_ server: CrackServer) -> [[String]] {
        var codes: [[String]] = [[]]
        for _ in 0..<server.codeLength {
            var longer: [[String]] = []
            for code in codes {
                for symbol in server.symbols where code.count(where: { $0 == symbol }) < server.maxRepeats {
                    longer.append(code + [symbol])
                }
            }
            codes = longer
        }
        return codes
    }
}
