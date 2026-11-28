package import CarrierCore
package import Foundation

/// One sandbox fight as the terminal runs it: the engine, the state, the
/// log of rendered events, and the replay being recorded.
package struct FightSession {
    package let engine: Engine
    package private(set) var state: GameState
    package private(set) var log: [String] = []
    package private(set) var replay: FightReplay
    package let recordURL: URL?

    package var content: ContentPack { engine.content }
    package var fight: FightState { state.fight }

    package init(engine: Engine, setup: FightSetup, rules: RuleSet, replay: FightReplay, recordURL: URL?) {
        self.engine = engine
        self.replay = replay
        self.recordURL = recordURL
        let (state, events) = engine.startFight(setup, rules: rules)
        self.state = state
        append(events)
    }

    package var parser: CommandParser {
        CommandParser(
            handNames: fight.hand.compactMap { content.card($0.cardID)?.name },
            allCardNames: Set(content.cards.map(\.name))
        )
    }

    /// Sends an action to the engine and records it.
    package mutating func perform(_ action: Action) throws {
        let (next, events) = engine.apply(action, to: state)
        state = next
        append(events)
        if case .actionRejected = events.first, events.count == 1 { return }
        replay.actions.append(action)
        try saveReplay()
    }

    /// A line the player typed, echoed into the log first.
    package mutating func submit(_ text: String) throws -> ParsedCommand {
        let command = parser.parse(text)
        switch command {
        case .play(let index):
            // The engine's card-played event is the echo.
            try perform(.play(handIndex: index))
        case .endTurn:
            note(">END")
            try perform(.endTurn)
        case .logout:
            note(">LOGOUT")
            try perform(.logout)
        case .help:
            note(">HELP")
            showHelp()
        case .info(let index):
            note(">INFO \(index == 9 ? 0 : index + 1)")
            showInfo(index)
        case .notInHand(let name):
            note(">\(name)")
            note("?\(name) NOT IN HAND")
        case .unknown(let input):
            note(">\(input)")
            note("?SYNTAX ERROR")
        case .quit, .empty:
            break
        }
        return command
    }

    /// Adds lines to the log, wrapped to the screen.
    package mutating func note(_ line: String) {
        log += Columns.wrap(line, indent: " ")
    }

    private mutating func append(_ events: [Event]) {
        for event in events {
            note(event.line(content: content))
        }
    }

    private mutating func showHelp() {
        note("1-9 OR NAME: RUN A CARD. TAB COMPLETES.")
        note("INFO N: WHAT CARD N DOES, IN FULL.")
        note("END: END TURN. LOGOUT: LEAVE (TRACE +\(state.rules.tuning.trace.logout)).")
        for line in CardText.glossary() { note(line) }
    }

    private mutating func showInfo(_ index: Int) {
        guard fight.hand.indices.contains(index), let card = content.card(fight.hand[index].cardID) else {
            note("?NO CARD \(index &+ 1)")
            return
        }
        let lines = CardText.details(
            card, numbers: [index], revealedWeak: fight.revealed ? fight.machine.weak : nil,
            revealedResist: fight.revealed ? fight.machine.resist : nil)
        for line in lines { note(line) }
    }

    private func saveReplay() throws {
        guard let recordURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(replay).write(to: recordURL)
    }

    /// Writes the replay once at the start, so an aborted session leaves one.
    package func start() throws {
        try saveReplay()
    }
}
