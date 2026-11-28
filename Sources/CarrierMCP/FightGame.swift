import CarrierCore
import CarrierGen
import CarrierTerminal
import Foundation

/// One sandbox fight in the server (`carrier fight`): the terminal's
/// `FightSession`, which drives `Engine` and records the replay.
struct FightGame {
    private(set) var session: FightSession

    init(seed: UInt64, role: NodeRole, payload: Int?, content: ContentPack) throws(GenerationError) {
        let setup = try SandboxFight.setup(seed: seed, role: role, payload: payload, content: content)
        // The sandbox has no contract, so it runs under the base rules, as
        // `carrier fight` does.
        let rules = RuleSet.defaults(content: content, objective: nil)
        session = FightSession(
            engine: Engine(content: content), setup: setup, rules: rules,
            replay: FightReplay(
                carrierVersion: CarrierVersion.current, seed: seed, role: role, payload: payload, rules: rules),
            recordURL: nil)
    }

    var menu: [MenuItem<Action>] { ActionMenu.fight(context) }

    private var context: FightContext { FightContext(sandbox: session.state, engine: session.engine) }

    /// Takes an action id or a typed command. A refused input leaves the
    /// game exactly as it was.
    mutating func act(_ input: String) -> ActOutcome {
        let before = session
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return ActOutcome(status: .rejected, lines: ["?EMPTY ACTION"]) }
        let actions = session.replay.actions.count
        var command: ParsedCommand?
        do {
            if let action = ActionMenu.fightAction(id: trimmed) {
                try session.perform(action)
            } else {
                command = session.parser.parse(trimmed)
                if command == .quit {
                    return ActOutcome(status: .rejected, lines: ["?USE end_game TO LEAVE A GAME"])
                }
                _ = try session.submit(trimmed)
            }
        } catch {
            session = before
            return ActOutcome(status: .rejected, lines: ["?INTERNAL ERROR: \(error)"])
        }
        let lines = Array(session.log.dropFirst(before.log.count))
        if session.replay.actions.count > actions { return ActOutcome(status: .ok, lines: lines) }
        if command == .help { return ActOutcome(status: .info, lines: lines) }
        session = before
        return ActOutcome(status: .rejected, lines: lines.filter { !$0.hasPrefix(">") })
    }

    func view(_ detail: ViewDetail) -> JSONValue {
        let fight = session.fight
        var fields: [String: JSONValue] = [
            "phase": .string(fight.isOver ? "over" : "fight"),
            "screen": .strings(FightScreen(session: session, style: .plain).lines(prompt: "", hint: "")),
            "legal_actions": .array(menu.map(\.json)),
        ]
        if let outcome = fight.outcome { fields["outcome"] = .string(outcome.rawValue) }
        guard detail == .full else { return .object(fields) }
        fields["fight"] = FightPanel.json(context)
        return .object(fields)
    }
}
