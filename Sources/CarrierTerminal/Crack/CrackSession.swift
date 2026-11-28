package import CarrierCore

/// A crack run as the terminal plays it: the run engine, the state, the log.
/// A single crack is a run of one server.
package struct CrackSession {
    package let engine: CrackRunEngine
    package private(set) var state: CrackRunState
    package private(set) var log: [String] = []
    /// One flag per log line: whether it is card text, whose keywords the
    /// screen shows in bold.
    package private(set) var logIsCardText: [Bool] = []
    package private(set) var actions: [CrackRunAction] = []
    /// The crack under way, or the last one once the run is past it. Nil
    /// only for a run with no servers, which validation refuses.
    package var crack: CrackState? { state.currentOrLastCrack }

    package init(engine: CrackRunEngine, seed: UInt64) {
        self.engine = engine
        let (state, events) = engine.start(seed: seed)
        self.state = state
        append(events)
    }

    package var crackEngine: CrackEngine { engine.crack }

    package mutating func perform(_ action: CrackRunAction) {
        let (next, events) = engine.apply(action, to: state)
        state = next
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
        case .define(let word):
            note(">? " + word.uppercased())
            if let keyword = engine.content.keyword(word) {
                note("\(keyword.word): \(keyword.text)", cardText: true)
            } else {
                let known = engine.content.keywords.map(\.word).joined(separator: " ")
                note("?NOT A KEYWORD. KEYWORDS: \(known)")
            }
        case .unknown(let typed):
            note(">" + typed)
            note("?SYNTAX ERROR. TYPE HELP.")
        case .quit, .empty:
            break
        }
        return input
    }

    package mutating func note(_ line: String, cardText: Bool = false) {
        let lines = Columns.wrap(line, indent: " ")
        log += lines
        logIsCardText += Array(repeating: cardText, count: lines.count)
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
        note(crack.server.feedback.legend)
        note("1 3: HAND CARD 1 ON SLOT 3. 1: PLAY CARD 1 ON ITS OWN.")
        note("T 2 K: TURN THE DIAL IN SLOT 2 TO K (\(costs.turn) EN A STEP). A DIAL SHOWS ~.")
        note("S 1 2: SWAP SLOTS 1 AND 2 (\(costs.swap) EN)")
        note("D 1: DROP HAND CARD 1 (\(costs.drop) EN). DROP CARDS YOU DO NOT NEED, OR YOUR HAND CLOGS.")
        note("G: GUESS. H: HOLD, NO GUESS (ALARM +\(engine.content.alarm.hold)). LOGOUT.")
        note("INFO: WHAT EACH CARD IN HAND DOES. ? WORD: A BOLD WORD.")
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
            note("\(definition.label) (\(crackEngine.playCost(card)) EN): \(definition.rules)", cardText: true)
        }
        note("? WORD: WHAT A BOLD WORD MEANS.")
    }

    /// The deck, numbered for REMOVE.
    package func deckLine() -> String {
        let cards = state.deck.enumerated().map {
            "\($0.offset + 1):" + (engine.content.card($0.element)?.label ?? $0.element)
        }
        return "DECK \(state.deck.count)/\(engine.content.run.deckLimit): " + cards.joined(separator: " ")
    }
}
