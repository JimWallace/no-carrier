package import CarrierCore

/// One crack as the terminal runs it: the engine, the state and the log.
package struct CrackSession {
    package let engine: CrackEngine
    package private(set) var state: CrackState
    package private(set) var log: [String] = []
    package private(set) var actions: [CrackAction] = []

    package init(engine: CrackEngine, seed: UInt64, server: CrackServer) {
        self.engine = engine
        let (state, events) = engine.start(seed: seed, server: server)
        self.state = state
        append(events)
    }

    package mutating func perform(_ action: CrackAction) {
        let (next, events) = engine.apply(action, to: state)
        state = next
        append(events)
        if case .rejected = events.first { return }
        actions.append(action)
    }

    /// A line the player typed, echoed into the log first.
    @discardableResult
    package mutating func submit(_ text: String) -> CrackInput {
        let input = CrackInput.parse(text)
        switch input {
        case .action(let action):
            note(">" + text.uppercased())
            perform(action)
        case .help:
            showHelp()
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

    private mutating func append(_ events: [CrackEvent]) {
        for event in events { note(event.line) }
    }

    private mutating func showHelp() {
        let costs = engine.content.costs
        note("FIND THE HIDDEN CODE.")
        switch state.server.feedback {
        case .counts:
            note("HIT: RIGHT SYMBOL, RIGHT SLOT.")
            note("NEAR: RIGHT SYMBOL, WRONG SLOT.")
        case .hits:
            note("THIS SERVER COUNTS HITS ONLY: RIGHT SYMBOL, RIGHT SLOT.")
        case .slots:
            note("A MARK PER SLOT. H: RIGHT SYMBOL. N: IN THE CODE, ANOTHER SLOT. -: NOT THERE.")
        }
        note("1 3: HAND CARD 1 TO SLOT 3 (\(costs.place) EN)")
        note("A PROBE ON A SLOT SHOWS ITS SYMBOL (\(costs.probe) EN).")
        note("T 2 K: TURN THE DIAL IN SLOT 2 TO K (\(costs.turn) EN A STEP).")
        note("A DIAL SHOWS ~ ON THE BOARD.")
        note("S 1 2: SWAP SLOTS 1 AND 2 (\(costs.swap) EN)")
        note("D 1: DROP HAND CARD 1 (\(costs.drop) EN). DROP CARDS YOU DO NOT NEED, OR YOUR HAND CLOGS.")
        note("G: GUESS. LOGOUT.")
        for program in state.server.interference {
            switch program.kind {
            case .scramble: note("SCRAMBLE: THE SERVER SWAPS TWO OF YOUR SLOTS.")
            case .rotate: note("ROTATE: THE CODE MOVES ONE SLOT RIGHT. THE LAST WRAPS TO THE FIRST.")
            }
        }
    }
}
