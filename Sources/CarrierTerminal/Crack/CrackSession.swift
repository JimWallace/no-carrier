package import CarrierCore

/// One crack as the terminal runs it: the engine, the state and the log.
package struct CrackSession {
    package let engine: CrackEngine
    package private(set) var state: CrackState
    package private(set) var log: [String] = []
    package private(set) var actions: [CrackAction] = []

    package init(engine: CrackEngine, seed: UInt64) {
        self.engine = engine
        let (state, events) = engine.start(seed: seed)
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
        note("HIT: RIGHT SYMBOL, RIGHT SLOT.")
        note("NEAR: RIGHT SYMBOL, WRONG SLOT.")
        note("1 3: HAND CARD 1 TO SLOT 3 (\(costs.place) EN)")
        note("S 1 2: SWAP SLOTS 1 AND 2 (\(costs.swap) EN)")
        note("D 1: DROP HAND CARD 1 (\(costs.drop) EN)")
        note("G: GUESS (ALARM +\(engine.content.alarm.perGuess)). LOGOUT.")
    }
}
