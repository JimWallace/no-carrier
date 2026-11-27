import CarrierCore

/// Lays out one frame of the fight in 40 columns (kickoff §7).
struct FightScreen {
    let engine: Engine
    let fight: FightState
    let log: [String]
    let style: Phosphor
    /// The terminal height. The log takes whatever the rest leaves, at least
    /// `minimumLogRows`.
    let screenRows: Int
    static let minimumLogRows = 3

    private var content: ContentPack { engine.content }

    init(engine: Engine, fight: FightState, log: [String], style: Phosphor, screenRows: Int = 24) {
        self.engine = engine
        self.fight = fight
        self.log = log
        self.style = style
        self.screenRows = screenRows
    }

    init(session: FightSession, style: Phosphor, screenRows: Int = 24) {
        self.init(engine: session.engine, fight: session.fight, log: session.log, style: style, screenRows: screenRows)
    }
    private let rule = String(repeating: "-", count: Columns.textWidth)

    func lines(prompt: String?, hint: String) -> [String] {
        let top = header() + iceAndLayers() + [rule]
        var bottom = [rule] + status() + hand()
        if let prompt {
            bottom.append(">" + prompt + style.blink("_"))
            bottom.append(hint)
        }
        let logRows = max(Self.minimumLogRows, screenRows - top.count - bottom.count)
        let shown = log.suffix(logRows)
        return top + shown + Array(repeating: "", count: max(0, logRows - shown.count)) + bottom
    }

    private func header() -> [String] {
        let machine = fight.machine
        let title = Columns.spread("\(machine.osName) \(machine.osVersion)", "TURN \(fight.turn)")
        let traceMax = content.tuning.trace.max
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
        for telegraph in engine.telegraph(fight) {
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
    private func hand() -> [String] {
        var cells: [String] = []
        for (index, instance) in fight.hand.enumerated() {
            let card = content.card(instance.cardID)
            let number = index == 9 ? "0" : "\(index + 1)"
            let cell = pad("\(number) \(pad(card?.name ?? instance.cardID, 14)) \(card?.cost.label ?? "?")", 19)
            let playable = engine.rejection(forPlaying: index, in: fight) == nil
            cells.append(playable ? cell : style.dim(cell))
        }
        if cells.isEmpty { return ["(NO CARDS IN HAND)"] }
        return stride(from: 0, to: cells.count, by: 2).map { start in
            cells[start..<min(start + 2, cells.count)].joined()
        }
    }

    private func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }

    private func padLeft(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : String(repeating: " ", count: width - text.count) + text
    }
}
