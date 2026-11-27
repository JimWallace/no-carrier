import CarrierCore
import Foundation

/// One sandbox fight as the terminal runs it: the engine, the state, the
/// log of rendered events, and the replay being recorded.
struct FightSession {
    let engine: Engine
    private(set) var state: GameState
    private(set) var log: [String] = []
    private(set) var replay: FightReplay
    let recordURL: URL?

    var content: ContentPack { engine.content }
    var fight: FightState { state.fight }

    init(engine: Engine, setup: FightSetup, replay: FightReplay, recordURL: URL?) {
        self.engine = engine
        self.replay = replay
        self.recordURL = recordURL
        let (state, events) = engine.startFight(setup)
        self.state = state
        append(events)
    }

    var parser: CommandParser {
        CommandParser(
            handNames: fight.hand.compactMap { content.card($0.cardID)?.name },
            allCardNames: Set(content.cards.map(\.name))
        )
    }

    /// Sends an action to the engine and records it.
    mutating func perform(_ action: Action) throws {
        let (next, events) = engine.apply(action, to: state)
        state = next
        append(events)
        replay.actions.append(action)
        try saveReplay()
    }

    /// A line the player typed, echoed into the log first.
    mutating func submit(_ text: String) throws -> ParsedCommand {
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
    mutating func note(_ line: String) {
        log += Columns.wrap(line, indent: " ")
    }

    private mutating func append(_ events: [Event]) {
        for event in events {
            note(event.line(content: content))
        }
    }

    private mutating func showHelp() {
        note("1-9 OR NAME: RUN A CARD. TAB COMPLETES.")
        note("END: END TURN. LOGOUT: LEAVE (TRACE +\(content.tuning.trace.logout)).")
        for instance in fight.hand {
            guard let card = content.card(instance.cardID) else { continue }
            note("\(card.name) \(card.cost.label): \(card.summary)")
        }
    }

    private func saveReplay() throws {
        guard let recordURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(replay).write(to: recordURL)
    }

    /// Writes the replay once at the start, so an aborted session leaves one.
    func start() throws {
        try saveReplay()
    }
}
