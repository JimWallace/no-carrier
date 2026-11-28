import CarrierCore
import CarrierGen
import CarrierTerminal
import Foundation

/// One contract in the server: the terminal's `PlaySession`, which drives
/// `ContractEngine`, keeps the log and records the replay.
struct ContractGame {
    private(set) var session: PlaySession

    var state: ContractState { session.state }
    var content: ContentPack { session.content }

    init(
        seed: UInt64, objective: ObjectiveDefinition, rules: RuleSet, content: ContentPack
    ) throws(GenerationError) {
        let network = try NetworkGenerator(content: content).generate(seed: seed)
        session = PlaySession(
            engine: ContractEngine(content: content), seed: seed, network: network, objective: objective,
            rules: rules, recordURL: nil)
    }

    /// Every mechanic flag and whether it is on, as `carrier rules` lists
    /// them. The rules are public: a human reads them the same way.
    var flags: JSONValue {
        var fields: [String: JSONValue] = [:]
        for flag in MechanicFlag.allCases { fields[flag.rawValue] = .bool(state.rules.isOn(flag)) }
        return .object(fields)
    }

    /// The flags that differ from the objective's defaults, as `name=on` or
    /// `name=off`, in `MechanicFlag.allCases` order.
    var changedFlags: [String] {
        let defaults = RuleSet.defaults(content: content, objective: state.objective)
        return MechanicFlag.allCases.filter { state.rules.isOn($0) != defaults.isOn($0) }.map {
            "\($0.rawValue)=\(state.rules.isOn($0) ? "on" : "off")"
        }
    }

    var menu: [MenuItem<ContractAction>] { ActionMenu.contract(state, engine: session.engine) }

    /// Takes an action id or a typed command. A refused input leaves the
    /// game exactly as it was.
    mutating func act(_ input: String) -> ActOutcome {
        let before = session
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let upper = trimmed.uppercased()
        if upper == "QUIT" || upper == "EXIT" {
            return ActOutcome(status: .rejected, lines: ["?USE end_game TO LEAVE A GAME"])
        }
        if trimmed.isEmpty { return ActOutcome(status: .rejected, lines: ["?EMPTY ACTION"]) }
        let actions = session.replay.actions.count
        let pending = session.pendingReward
        do {
            if let action = ActionMenu.contractAction(id: trimmed) {
                session.cancelPendingReward()
                try session.perform(action)
            } else {
                _ = try session.submit(trimmed)
            }
        } catch {
            session = before
            return ActOutcome(status: .rejected, lines: ["?INTERNAL ERROR: \(error)"])
        }
        let lines = Array(session.log.dropFirst(before.log.count))
        let refused = lines.contains { $0.hasPrefix("?") }
        // The fight engine refuses a card inside a contract without the
        // contract engine refusing the action, so the terminal records it.
        // The state is unchanged; undo it here, so the replay stays clean.
        if session.replay.actions.count > actions && !(refused && session.state == before.state) {
            return ActOutcome(status: .ok, lines: lines)
        }
        if session.pendingReward != pending { return ActOutcome(status: .info, lines: lines) }
        if state.outcome != nil && lines.isEmpty {
            session = before
            return ActOutcome(status: .rejected, lines: [ContractRejectReason.contractOver.line])
        }
        if refused {
            session = before
            return ActOutcome(status: .rejected, lines: lines.filter { !$0.hasPrefix(">") })
        }
        return ActOutcome(status: .info, lines: lines)
    }

    // MARK: - View

    func view(_ detail: ViewDetail) -> JSONValue {
        var fields: [String: JSONValue] = [
            "phase": .string(phaseName),
            "screen": .strings(screen),
            "legal_actions": .array(menu.map(\.json)),
        ]
        if state.outcome != nil {
            fields["outcome"] = .strings(session.banner)
        }
        guard detail == .full else { return .object(fields) }
        let map = MapScreen(state: state, content: content, style: .plain)
        fields["objective"] = [
            "id": .string(state.objective.id),
            "name": .string(state.objective.name),
        ]
        fields["flags"] = flags
        fields["flags_changed"] = .strings(changedFlags)
        fields["status"] = status
        fields["sysop_next"] = .string(map.sysopLine())
        fields["map"] = PlayerMap.json(state, content: content)
        fields["deck"] = .array(deckCounts)
        switch state.phase {
        case .fight(let node, _, _), .accessChoice(let node, _, _):
            var panel = FightContext(contract: state, engine: session.engine).map(FightPanel.json) ?? .null
            if case .object(var panelFields) = panel {
                panelFields["node"] = .int(node)
                panel = .object(panelFields)
            }
            fields["fight"] = panel
        case .reward(_, let choices):
            fields["loot"] = .array(choices.enumerated().map { cardJSON($1, number: $0 + 1) })
            fields["storage_full"] = .bool(state.deck.count >= state.storage)
        case .upgrade(_, let choices, _):
            fields["upgrades"] = .strings(choices.map(\.label))
        default:
            break
        }
        return .object(fields)
    }

    /// The frame a human sees at a 24-row terminal, without colour.
    var screen: [String] {
        session.screen(style: .plain, rows: 24, prompt: "", hint: "")
    }

    var phaseName: String {
        switch state.phase {
        case .map: "map"
        case .fight: "fight"
        case .accessChoice: "access_choice"
        case .reward: "loot"
        case .upgrade: "upgrade"
        case .over: "over"
        }
    }

    private var status: JSONValue {
        let alert = state.rules.tuning.network.alert
        var fields: [String: JSONValue] = [
            "tick": .int(state.tick),
            "trace": .int(state.trace),
            "trace_max": .int(state.rules.tuning.trace.max),
            "alert": .int(state.alert),
            "alert_max": .int(alert.max),
            "alert_state": .string(state.alertState.label),
            "integrity": .int(state.integrity),
            "max_integrity": .int(state.rig.maxIntegrity),
            "deck_size": .int(state.deck.count),
            "storage": .int(state.storage),
            "cycles": .int(state.rig.cycles),
            "ram": .int(state.rig.ram),
        ]
        if let target = state.targetNode {
            fields["target"] = [
                "node": .int(target),
                "file_mb": .int(state.fileMB),
                "have_file": .bool(state.hasFile),
            ]
        }
        return .object(fields)
    }

    /// The deck between fights, as DECK prints it: each card once, with a
    /// count, in the order of the first copy.
    private var deckCounts: [JSONValue] {
        var counts: [(String, Int)] = []
        for id in state.deck {
            if let index = counts.firstIndex(where: { $0.0 == id }) {
                counts[index].1 += 1
            } else {
                counts.append((id, 1))
            }
        }
        return counts.map { id, count in
            var card = cardJSON(id, number: nil)
            if case .object(var fields) = card {
                fields["count"] = .int(count)
                card = .object(fields)
            }
            return card
        }
    }

    private func cardJSON(_ id: String, number: Int?) -> JSONValue {
        guard let card = content.card(id) else { return ["name": .string(id)] }
        var fields: [String: JSONValue] = [
            "name": .string(card.name),
            "type": .string(card.type.label),
            "cost": .string(card.cost.label),
            "rules": .string(card.summary),
        ]
        if let number { fields["choice"] = .int(number) }
        if !card.tags.isEmpty { fields["tags"] = .strings(card.tags.map(\.label)) }
        return .object(fields)
    }
}
