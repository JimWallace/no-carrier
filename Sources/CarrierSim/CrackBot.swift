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

    public init(engine: CrackEngine) {
        self.engine = engine
        candidates = Self.allCodes(engine.content)
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
        if let probe = probe(state) { return probe }
        guard let target = target(state) else { return .guess }
        return step(toward: target, in: state) ?? drop(keeping: target, in: state) ?? .guess
    }

    /// With energy left and nothing to fix, drops a card the target does
    /// not need, so the next turn draws something new. Probes and dials are
    /// kept.
    private func drop(keeping target: [String], in state: CrackState) -> CrackAction? {
        var needed = target
        for slot in state.board.compactMap({ $0?.symbol }) {
            if let index = needed.firstIndex(of: slot) { needed.remove(at: index) }
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

    /// Drops every candidate that a new guess or a probe rules out.
    private mutating func learn(_ state: CrackState) {
        let newGuesses = state.guesses.dropFirst(guessesSeen)
        guessesSeen = state.guesses.count
        let revealed = state.revealed
        candidates = candidates.filter { code in
            for (slot, symbol) in revealed.enumerated() where symbol != nil && code[slot] != symbol {
                return false
            }
            return newGuesses.allSatisfy { CrackFeedback.score(guess: $0.symbols, code: code) == $0.feedback }
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

    /// Every code the content can make, in order.
    static func allCodes(_ content: CrackContent) -> [[String]] {
        var codes: [[String]] = [[]]
        for _ in 0..<content.codeLength {
            var longer: [[String]] = []
            for code in codes {
                for symbol in content.symbols where code.count(where: { $0 == symbol }) < content.maxRepeats {
                    longer.append(code + [symbol])
                }
            }
            codes = longer
        }
        return codes
    }
}
