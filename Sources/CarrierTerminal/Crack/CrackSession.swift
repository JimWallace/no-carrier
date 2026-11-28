package import CarrierCore

/// A crack run as the terminal plays it: the run engine, the state, the log.
/// A single crack is a run of one server.
package struct CrackSession {
    package let engine: CrackRunEngine
    package private(set) var state: CrackRunState
    package private(set) var log: [String] = []
    package private(set) var actions: [CrackRunAction] = []
    /// The crack under way, or the last one once the run is past it. Nil
    /// only for a run with no servers, which validation refuses.
    package private(set) var crack: CrackState?

    package init(engine: CrackRunEngine, seed: UInt64) {
        self.engine = engine
        let (state, events) = engine.start(seed: seed)
        self.state = state
        if case .cracking(let crack) = state.phase { self.crack = crack }
        append(events)
    }

    package var crackEngine: CrackEngine { engine.crack }

    package mutating func perform(_ action: CrackRunAction) {
        // The crack's own state after the action, kept even when the action
        // ends the crack and the run moves on.
        if case .crack(let inner) = action, case .cracking(let current) = state.phase {
            crack = crackEngine.apply(inner, to: current).0
        }
        let (next, events) = engine.apply(action, to: state)
        state = next
        if case .cracking(let current) = next.phase { crack = current }
        append(events)
        if case .rejected = events.first { return }
        if case .crack(.rejected) = events.first, events.count == 1 { return }
        actions.append(action)
    }

    /// A line the player typed, echoed into the log first.
    @discardableResult
    package mutating func submit(_ text: String) -> CrackInput {
        let input = CrackInput.parse(text)
        switch input {
        case .action(let action):
            note(">" + text.uppercased())
            perform(.crack(action))
        case .reward(let action):
            note(">" + text.uppercased())
            perform(action)
        case .help:
            showHelp()
        case .info:
            showInfo()
        case .deck:
            note(">DECK")
            note(deckLine())
        case .unknown(let typed):
            note(">" + typed)
            note("?SYNTAX ERROR. TYPE HELP.")
        case .quit, .empty:
            break
        }
        return input
    }

    package mutating func note(_ line: String) {
        log += Columns.wrap(line, indent: " ")
    }

    private mutating func append(_ events: [CrackRunEvent]) {
        for event in events {
            note(event.line { engine.content.card($0)?.label ?? $0 })
        }
    }

    private mutating func showHelp() {
        if case .reward = state.phase {
            note("TAKE 1: ADD OFFERED CARD 1 TO YOUR DECK.")
            note("REMOVE 5: TAKE DECK CARD 5 OUT INSTEAD.")
            note("SKIP: NEITHER. DECK LIMIT \(engine.content.run.deckLimit).")
            return
        }
        guard let crack else { return }
        let costs = engine.content.costs
        note("FIND THE HIDDEN CODE.")
        switch crack.server.feedback {
        case .counts:
            note("HIT: RIGHT SYMBOL, RIGHT SLOT.")
            note("NEAR: RIGHT SYMBOL, WRONG SLOT.")
        case .hits:
            note("THIS SERVER COUNTS HITS ONLY: RIGHT SYMBOL, RIGHT SLOT.")
        case .slots:
            note("A MARK PER SLOT. H: RIGHT SYMBOL. N: IN THE CODE, ANOTHER SLOT. -: NOT THERE.")
        }
        note("1 3: HAND CARD 1 ON SLOT 3. 1: PLAY CARD 1 ON ITS OWN.")
        note("T 2 K: TURN THE DIAL IN SLOT 2 TO K (\(costs.turn) EN A STEP). A DIAL SHOWS ~.")
        note("S 1 2: SWAP SLOTS 1 AND 2 (\(costs.swap) EN)")
        note("D 1: DROP HAND CARD 1 (\(costs.drop) EN). DROP CARDS YOU DO NOT NEED, OR YOUR HAND CLOGS.")
        note("G: GUESS. H: HOLD, NO GUESS (ALARM +\(engine.content.alarm.hold)). LOGOUT.")
        note("INFO: WHAT EACH CARD IN HAND DOES.")
        note("DECK: YOUR WHOLE DECK.")
        for program in crack.server.interference {
            switch program.kind {
            case .scramble: note("SCRAMBLE: THE SERVER SWAPS TWO OF YOUR SLOTS. A LOCKED SLOT IS SAFE.")
            case .rotate: note("ROTATE: THE CODE MOVES ONE SLOT RIGHT. THE LAST WRAPS TO THE FIRST.")
            }
        }
    }

    /// Every card in hand and what it does, copies once.
    private mutating func showInfo() {
        note(">INFO")
        guard case .cracking = state.phase, let crack else { return }
        var seen: [String] = []
        for card in crack.hand where !seen.contains(card.cardID) {
            seen.append(card.cardID)
            guard let definition = engine.content.card(card.cardID) else { continue }
            note("\(definition.label) (\(crackEngine.playCost(card)) EN): \(definition.rules)")
        }
    }

    /// The deck, numbered for REMOVE.
    package func deckLine() -> String {
        let cards = state.deck.enumerated().map {
            "\($0.offset + 1):" + (engine.content.card($0.element)?.label ?? $0.element)
        }
        return "DECK \(state.deck.count)/\(engine.content.run.deckLimit): " + cards.joined(separator: " ")
    }
}
