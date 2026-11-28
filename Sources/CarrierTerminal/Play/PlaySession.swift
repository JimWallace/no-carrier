package import CarrierCore
package import Foundation

/// One contract as the terminal runs it: the engine, the state, the log
/// and the replay being recorded.
package struct PlaySession {
    package let engine: ContractEngine
    package private(set) var state: ContractState
    package private(set) var log: [String] = []
    package private(set) var replay: ContractReplay
    package let recordURL: URL?
    /// A loot card chosen while Storage is full, waiting for the card to
    /// delete for it.
    package private(set) var pendingReward: Int?

    package var content: ContentPack { engine.content }

    package init(
        engine: ContractEngine, seed: UInt64, network: Network, objective: ObjectiveDefinition, rules: RuleSet,
        recordURL: URL?
    ) {
        self.engine = engine
        self.recordURL = recordURL
        replay = ContractReplay(
            carrierVersion: CarrierVersion.current, seed: seed, objective: objective.id, rules: rules)
        let (state, events) = engine.start(seed: seed, network: network, objective: objective, rules: rules)
        self.state = state
        note("OBJECTIVE: \(objective.name)")
        append(events)
        note("TYPE HELP FOR COMMANDS.")
    }

    /// Sends an action. Only accepted actions go into the replay. Returns
    /// whether the engine accepted it.
    @discardableResult
    package mutating func perform(_ action: ContractAction) throws -> Bool {
        let (next, events) = engine.apply(action, to: state)
        state = next
        append(events)
        if case .actionRejected = events.first, events.count == 1 { return false }
        replay.actions.append(action)
        try saveReplay()
        return true
    }

    package mutating func note(_ line: String) {
        log += Columns.wrap(line, indent: " ")
    }

    private mutating func append(_ events: [ContractEvent]) {
        for event in events {
            if let node = Self.node(named: event), state.network.nodes.indices.contains(node),
                state.network.nodes[node].visibility == .hidden
            {
                // The fog hides the node, so the sysop's move on it is vague.
                note("SYSOP: ACTIVITY ON AN UNKNOWN NODE")
                continue
            }
            note(event.line(content: content))
            if case .rewardOffered(let ids) = event {
                for (index, id) in ids.enumerated() {
                    guard let card = content.card(id) else { continue }
                    note("\(index + 1) \(card.name) \(card.cost.label): \(card.summary)")
                }
                note("0 SKIP")
            }
            if case .upgradeOffered(let choices) = event {
                for (index, upgrade) in choices.enumerated() {
                    note("\(index + 1) \(upgrade.label)")
                }
            }
        }
    }

    /// The node a sysop event names, when the fog could hide it.
    private static func node(named event: ContractEvent) -> Int? {
        switch event {
        case .sysopTelegraphed(let intent), .sysopActed(let intent), .sysopFizzled(let intent):
            switch intent {
            case .contest(let node), .harden(let node), .spawnICE(let node, _), .revoke(let node): node
            case .sweep: nil
            }
        case .nodeHardened(let node, _, _, _), .iceSpawned(let node, _): node
        default: nil
        }
    }

    package func start() throws {
        try saveReplay()
    }

    private func saveReplay() throws {
        guard let recordURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(replay).write(to: recordURL)
    }

    // MARK: - Input

    /// Digits act at once except while a deck number (which can be above 9)
    /// is being typed.
    package var immediateDigits: Bool { pendingReward == nil }

    /// Drops a half-made storage-full choice, when the action was given
    /// another way (the MCP server's action ids).
    package mutating func cancelPendingReward() {
        pendingReward = nil
    }

    package var completer: LineEditor.Completer {
        switch state.phase {
        case .map: return MapCommand.complete
        case .fight(_, let fight, _): return fightParser(fight).complete
        case .accessChoice: return { prefix in Self.completeWord(prefix, from: ["CLAIM", "GHOST"]) }
        case .reward: return { prefix in Self.completeWord(prefix, from: ["SKIP", "DECK", "CANCEL"]) }
        default: return { ($0.uppercased(), []) }
        }
    }

    private static func completeWord(_ prefix: String, from words: [String]) -> (text: String, matches: [String]) {
        let matches = words.filter { $0.hasPrefix(prefix.uppercased()) }
        return (matches.count == 1 ? matches[0] : prefix.uppercased(), matches)
    }

    private func fightParser(_ fight: FightState) -> CommandParser {
        CommandParser(
            handNames: fight.hand.compactMap { content.card($0.cardID)?.name },
            allCardNames: Set(content.cards.map(\.name))
        )
    }

    /// A number key on an empty prompt.
    package mutating func digit(_ digit: Int) throws {
        switch state.phase {
        case .map: try perform(.attack(node: digit))
        case .fight: try perform(.fight(.play(handIndex: CommandParser.handIndex(forDigit: digit))))
        case .accessChoice:
            if digit == 1 {
                try perform(.claim)
            } else if digit == 2 {
                try perform(.ghost)
            } else {
                note("?CLAIM (1) OR GHOST (2)")
            }
        default: _ = try submit(String(digit))
        }
    }

    /// A typed line. Returns false when the player quits.
    package mutating func submit(_ text: String) throws -> Bool {
        let input = text.uppercased().trimmingCharacters(in: .whitespaces)
        if input == "QUIT" || input == "EXIT" { return false }
        if input == "DECK" {
            note(">DECK")
            showDeck()
            return true
        }
        switch state.phase {
        case .map: try submitMap(input)
        case .fight(_, let fight, _): try submitFight(input, fight: fight)
        case .reward: try submitReward(input)
        case .accessChoice:
            if input == "CLAIM" || input == "1" {
                try perform(.claim)
            } else if input == "GHOST" || input == "2" {
                try perform(.ghost)
            } else if !input.isEmpty {
                note("?CLAIM (1) OR GHOST (2)")
            }
        case .upgrade:
            if let number = Int(input), number >= 1 {
                try perform(.chooseUpgrade(choice: number - 1))
            } else if !input.isEmpty {
                note("?TYPE 1 TO \(state.rules.tuning.network.dataUpgrades.count)")
            }
        case .over: break
        }
        return true
    }

    private mutating func submitMap(_ input: String) throws {
        switch MapCommand.parse(input) {
        case .attack(let node): try perform(.attack(node: node))
        case .reinforce(let node): try perform(.reinforce(node: node))
        case .wait: try perform(.wait)
        case .scan(let node): try perform(.scan(node: node))
        case .info(let node): info(node)
        case .jackOut: try perform(.jackOut)
        case .deck: showDeck()
        case .help: showMapHelp()
        case .quit, .empty: break
        case .unknown(let text):
            note(">\(text)")
            note("?SYNTAX ERROR")
        }
    }

    private mutating func submitFight(_ input: String, fight: FightState) throws {
        switch fightParser(fight).parse(input) {
        case .play(let index): try perform(.fight(.play(handIndex: index)))
        case .endTurn:
            note(">END")
            try perform(.fight(.endTurn))
        case .logout:
            note(">LOGOUT")
            try perform(.fight(.logout))
        case .help:
            note("1-9 OR NAME: RUN A CARD. INFO N: CARD N IN FULL. END. LOGOUT.")
            for line in CardText.glossary() { note(line) }
        case .info(let index):
            guard fight.hand.indices.contains(index), let card = content.card(fight.hand[index].cardID) else {
                note("?NO CARD \(index &+ 1)")
                return
            }
            let lines = CardText.details(
                card, numbers: [index], revealedWeak: fight.revealed ? fight.machine.weak : nil,
                revealedResist: fight.revealed ? fight.machine.resist : nil)
            for line in lines { note(line) }
        case .notInHand(let name): note("?\(name) NOT IN HAND")
        case .unknown(let text): note("?SYNTAX ERROR: \(text)")
        case .quit, .empty: break
        }
    }

    private mutating func submitReward(_ input: String) throws {
        if let pending = pendingReward {
            if input == "CANCEL" || input == "0" {
                pendingReward = nil
                note("CANCELLED")
            } else if let number = Int(input), number >= 1 {
                if try perform(.takeReward(choice: pending, replacing: number - 1)) {
                    pendingReward = nil
                }
            } else {
                note("?TYPE A DECK NUMBER, OR CANCEL")
            }
            return
        }
        if input == "SKIP" || input == "0" {
            try perform(.skipReward)
        } else if let number = Int(input), number >= 1 {
            guard case .reward(_, let choices) = state.phase, number <= choices.count else {
                note("?TYPE 1 TO \(rewardCount), OR 0 TO SKIP")
                return
            }
            if state.deck.count >= state.storage {
                pendingReward = number - 1
                note("STORAGE FULL. DELETE WHICH CARD?")
                showDeck(numbered: true)
                note("TYPE ITS NUMBER AND RETURN, OR CANCEL")
            } else {
                try perform(.takeReward(choice: number - 1, replacing: nil))
            }
        } else if !input.isEmpty {
            note("?TYPE 1 TO \(rewardCount), OR 0 TO SKIP")
        }
    }

    private var rewardCount: Int {
        if case .reward(_, let choices) = state.phase { return choices.count }
        return state.rules.tuning.network.rewardChoices
    }

    // MARK: - Information

    private mutating func showMapHelp() {
        note("ATTACK N (OR KEY N): BREAK INTO NODE N.")
        note("REINFORCE N: STOP A CONTEST OR REVOKE.")
        note("SCAN N: LEARN A DETECTED NODE (+ALERT).")
        note("WAIT: PASS THE TICK. INFO N: WHAT YOU KNOW.")
        note("JACK OUT: END THE CONTRACT. DECK. QUIT.")
        note("ONE ACTION PER TICK. KERNEL LAYERS NEED PAYLOAD (FROM VIRUS NODES).")
        note("EVERY CARD MAKES NOISE: ALERT WAKES THE SYSOP.")
    }

    private mutating func info(_ index: Int) {
        guard state.network.nodes.indices.contains(index), state.network.nodes[index].visibility != .hidden else {
            note("?NO NODE \(index)")
            return
        }
        let node = state.network.nodes[index]
        let machine = node.machine
        note(">INFO \(index)")
        guard node.visibility == .scanned else {
            note("NODE \(index): UNKNOWN. SCAN IT, OR PROBE IT IN A FIGHT.")
            return
        }
        note("NODE \(index) \(node.type.label) \(node.owner.rawValue.uppercased())\(node.accessed ? " ACCESSED" : "")")
        note("\(machine.osName) \(machine.osVersion) \(machine.hostname)")
        note("\(machine.cpu.name) \(machine.ramMB)MB \(machine.modem.name)")
        let ice = machine.ice.map { content.iceDefinition($0)?.name ?? $0 }
        note("ICE: \(ice.isEmpty ? "-" : ice.joined(separator: ", "))")
        note(machine.layers.map { "\($0.kind.label) \($0.hp)" }.joined(separator: " "))
    }

    private mutating func showDeck(numbered: Bool = false) {
        if numbered {
            for (index, id) in state.deck.enumerated() {
                note("\(index + 1) \(content.card(id)?.name ?? id)")
            }
            return
        }
        var counts: [(String, Int)] = []
        for id in state.deck {
            if let index = counts.firstIndex(where: { $0.0 == id }) {
                counts[index].1 += 1
            } else {
                counts.append((id, 1))
            }
        }
        let parts = counts.map { "\(content.card($0.0)?.name ?? $0.0) x\($0.1)" }
        note("DECK \(state.deck.count)/\(state.storage): " + parts.joined(separator: ", "))
    }

    // MARK: - Screen

    package func screen(
        style: Phosphor, rows: Int, prompt: String?, hint: String, columns: Int = Columns.width
    ) -> [String] {
        if case .fight(let node, let fight, _) = state.phase {
            return FightScreen(
                engine: engine.fightEngine, fight: fight, rules: state.rules, log: log, style: style, screenRows: rows,
                screenColumns: columns, place: "NODE \(node)"
            )
            .lines(prompt: prompt, hint: hint)
        }
        if case .accessChoice(let node, let fight, _) = state.phase {
            let choice = prompt.map { _ in "1 CLAIM (FIGHT ON)  2 GHOST (LEAVE)" }
            var lines = FightScreen(
                engine: engine.fightEngine, fight: fight, rules: state.rules, log: log, style: style,
                screenRows: rows - 1, screenColumns: columns, place: "NODE \(node)"
            )
            .lines(prompt: prompt, hint: hint)
            if let choice { lines.insert(style.inverse(choice), at: max(0, lines.count - 2)) }
            return lines
        }
        let map = MapScreen(state: state, content: content, style: style)
        let rule = String(repeating: "-", count: Columns.textWidth)
        let top = map.top() + [rule]
        var bottom = [rule]
        switch state.phase {
        case .map: bottom.append(map.targets())
        case .reward:
            bottom.append(pendingReward == nil ? "LOOT: 1-\(rewardCount) TAKE, 0 SKIP" : "DELETE: DECK NUMBER, CANCEL")
        case .upgrade: bottom.append("UPGRADE: 1-\(state.rules.tuning.network.dataUpgrades.count)")
        default: break
        }
        if let prompt {
            bottom.append(">" + prompt + style.blink("_"))
            bottom.append(hint)
        }
        let logRows = max(3, rows - top.count - bottom.count)
        let shown = log.suffix(logRows)
        let game = top + shown + Array(repeating: "", count: max(0, logRows - shown.count)) + bottom
        guard columns >= Columns.panelNeeds else { return game }
        return Columns.beside(game, Array(deckPanel(style: style).prefix(game.count)))
    }

    /// Beside the map: the deck, grouped, with what each card does.
    private func deckPanel(style: Phosphor) -> [String] {
        let width = Columns.panelWidth
        var lines = [style.inverse(CardText.pad("YOUR DECK \(state.deck.count)/\(state.storage)", width))]
        lines += CardText.deck(state.deck, content: content, width: width)
        lines.append("")
        lines += Columns.wrap("INFO IN A FIGHT: INFO N. HELP FOR THE KEY.", width: width)
        return lines
    }

    package var banner: [String] {
        var lines: [String]
        switch state.outcome {
        case .won:
            lines = [
                state.objective.win == .exfiltrate
                    ? "FILE DELIVERED. CONTRACT COMPLETE." : "ROOT ACCESS. CONTRACT COMPLETE."
            ]
            if let payout = state.payout { lines.append("PAYOUT: \(payout.label)") }
        case .flatlined: lines = ["INTEGRITY 0. RUN OVER."]
        case .traced: lines = ["", "NO CARRIER", ""]
        case .entryLost: lines = ["ENTRY LOST. CONTRACT FAILED."]
        case .jackedOut: lines = ["JACKED OUT. OBJECTIVE NOT MET."]
        case nil: lines = ["SESSION ABANDONED."]
        }
        let alert = state.rules.isOn(.alert) ? "\(state.alert)" : "OFF"
        lines.append("TICK \(state.tick) TRACE \(state.trace) ALERT \(alert) INT \(state.integrity)")
        return lines
    }
}
