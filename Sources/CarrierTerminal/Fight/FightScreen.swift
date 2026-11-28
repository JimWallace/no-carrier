package import CarrierCore

/// Lays out one frame of the fight in 40 columns (kickoff §7).
package struct FightScreen {
    package let engine: Engine
    package let fight: FightState
    package let rules: RuleSet
    package let log: [String]
    package let style: Phosphor
    /// The terminal height. The log takes whatever the rest leaves, at least
    /// `minimumLogRows`.
    package let screenRows: Int
    /// The terminal width. At `Columns.panelNeeds` or more, a card panel
    /// sits beside the game.
    package let screenColumns: Int
    /// Where the fight is, for the title bar: `NODE 4` in a contract.
    package let place: String?
    package static let minimumLogRows = 3

    private var content: ContentPack { engine.content }

    package init(
        engine: Engine, fight: FightState, rules: RuleSet, log: [String], style: Phosphor, screenRows: Int = 24,
        screenColumns: Int = Columns.width, place: String? = nil
    ) {
        self.engine = engine
        self.fight = fight
        self.rules = rules
        self.log = log
        self.style = style
        self.screenRows = screenRows
        self.screenColumns = screenColumns
        self.place = place
    }

    package init(session: FightSession, style: Phosphor, screenRows: Int = 24, screenColumns: Int = Columns.width) {
        self.init(
            engine: session.engine, fight: session.fight, rules: session.state.rules, log: session.log, style: style,
            screenRows: screenRows, screenColumns: screenColumns)
    }
    private let rule = String(repeating: "-", count: Columns.textWidth)

    package func lines(prompt: String?, hint: String) -> [String] {
        let top = header() + iceAndLayers() + [rule]
        var bottom = [rule] + status() + hand()
        if let prompt {
            bottom.append(">" + prompt + style.blink("_"))
            bottom.append(hint)
        }
        let logRows = max(Self.minimumLogRows, screenRows - top.count - bottom.count)
        let shown = log.suffix(logRows)
        let game = top + shown + Array(repeating: "", count: max(0, logRows - shown.count)) + bottom
        guard screenColumns >= Columns.panelNeeds else { return game }
        return Columns.beside(game, Array(panel().prefix(game.count)))
    }

    /// The card panel: every card in hand with its full rules, then the key.
    package func panel() -> [String] {
        let width = Columns.panelWidth
        var lines = [style.inverse(CardText.pad("YOUR HAND: WHAT EACH CARD DOES", width))]
        // Copies of one card share an entry: `3,4,5 BRUTE.EXE`.
        var groups: [(cardID: String, numbers: [Int])] = []
        for (index, instance) in fight.hand.enumerated() {
            if let group = groups.firstIndex(where: { $0.cardID == instance.cardID }) {
                groups[group].numbers.append(index)
            } else {
                groups.append((instance.cardID, [index]))
            }
        }
        for group in groups {
            guard let card = content.card(group.cardID) else { continue }
            lines += CardText.details(
                card, numbers: group.numbers, revealedWeak: fight.revealed ? fight.machine.weak : nil,
                revealedResist: fight.revealed ? fight.machine.resist : nil, width: width)
        }
        lines.append("")
        lines.append(style.inverse(CardText.pad("KEY", width)))
        lines += CardText.glossary(width: width)
        return lines
    }

    private func header() -> [String] {
        let machine = fight.machine
        let location = place.map { "\($0): " } ?? ""
        let title = Columns.spread("\(location)\(machine.osName) \(machine.osVersion)", "TURN \(fight.turn)")
        let traceMax = rules.tuning.trace.max
        let traceText = "TRACE " + Columns.bar(fight.trace, of: traceMax, cells: 20) + " \(fight.trace)"
        let tracing = fight.trace * 4 >= traceMax * 3
        return [
            style.inverse(title),
            orgLine(machine),
            "\(machine.cpu.name) \(machine.ramMB)MB \(machine.modem.name)",
            tracing ? style.blink(traceText) : traceText,
        ]
    }

    /// The org and the hostname when both fit, else the org alone (the log
    /// opens with the hostname).
    private func orgLine(_ machine: Machine) -> String {
        let both = "\(machine.orgName) \(machine.hostname)"
        return both.count <= Columns.textWidth ? both : String(machine.orgName.prefix(Columns.textWidth))
    }

    private func iceAndLayers() -> [String] {
        var lines: [String] = []
        for telegraph in engine.telegraph(fight, rules: rules) {
            let name = content.iceDefinition(telegraph.iceID)?.name ?? telegraph.iceID
            let intents = telegraph.intents.map(\.label).joined(separator: " + ")
            lines += Columns.wrap(pad(name, 11) + "> " + intents, indent: String(repeating: " ", count: 13))
        }
        if fight.ice.isEmpty {
            lines.append("NO ICE")
        }
        let current = fight.currentLayerIndex
        for (index, layer) in fight.machine.layers.enumerated() {
            let bar = Columns.bar(layer.hp, of: layer.maxHP, cells: 10)
            let line = pad(layer.kind.label, 9) + bar + " " + padLeft("\(layer.hp)/\(layer.maxHP)", 7)
            lines.append(index == current ? style.bright(line + " <") : line)
        }
        if let transfer = fight.transfer {
            let bar = Columns.bar(transfer.doneMB, of: transfer.totalMB, cells: 10)
            let line = pad("TRANSFER", 9) + bar + " " + padLeft("\(transfer.doneMB)/\(transfer.totalMB)MB", 7)
            lines.append(transfer.started && !transfer.isComplete ? style.bright(line + " <") : line)
        }
        let weak = fight.revealed ? MachineReadout.tags(fight.machine.weak) : "???"
        let resist = fight.revealed ? MachineReadout.tags(fight.machine.resist) : "???"
        lines += Columns.wrap("WEAK: \(weak)  RESIST: \(resist)")
        return lines
    }

    private func status() -> [String] {
        let usedRAM = fight.daemons.reduce(0) { $0 + (content.card($1.cardID)?.daemon?.ram ?? 0) }
        let daemons = fight.daemons.compactMap { content.card($0.cardID)?.name }
        var lines = [
            "CYC \(fight.cycles)/\(fight.rig.cycles) RAM \(usedRAM)/\(fight.rig.ram) PROXY \(fight.proxy)"
                + " INT \(fight.integrity)/\(fight.rig.maxIntegrity)",
            "DRAW \(fight.drawPile.count) DISCARD \(fight.discardPile.count) GONE \(fight.exhaustPile.count + fight.consumedCards.count)",
        ]
        if !daemons.isEmpty {
            lines += Columns.wrap("DMN: " + daemons.joined(separator: ", "), indent: "     ")
        }
        return lines
    }

    /// Two cards a line: number, name, cost. A card that cannot run now is
    /// dimmed.
    /// One card a line: number, name, cost, what it does. A card that
    /// cannot run now says why (`NO CYC: ATK 13`).
    private func hand() -> [String] {
        if fight.hand.isEmpty { return ["(NO CARDS IN HAND)"] }
        return fight.hand.enumerated().map { index, instance in
            guard let card = content.card(instance.cardID) else { return "\(index + 1) \(instance.cardID)" }
            let refusal = engine.rejection(forPlaying: index, in: fight, rules: rules)
            return CardText.handLine(number: index, card: card, refusal: refusal)
        }
    }

    private func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }

    private func padLeft(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : String(repeating: " ", count: width - text.count) + text
    }
}
