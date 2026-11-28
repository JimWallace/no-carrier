import CarrierCore
import SwiftGodot

/// A node fight: you on the left, the machine and its ICE on the right,
/// your hand along the bottom. Click a card to run it; END TURN lets the
/// ICE act.
enum BattleView {
    static var cardSize: Vector2 { Vector2(x: 176, y: 230) }

    static func make(
        _ session: ContractSession, node: Int, fight: FightState, send: @escaping (ContractAction) -> Void
    ) -> Control {
        let root = Phosphor.vbox(separation: 10)
        root.addChild(node: header(session, node: node, fight: fight))

        let arena = Phosphor.hbox(separation: 24)
        arena.sizeFlagsVertical = .expandFill
        arena.addChild(node: player(session, fight: fight))
        arena.addChild(node: ice(session))
        arena.addChild(node: machine(session, fight: fight))
        root.addChild(node: arena)

        root.addChild(node: LogPanel.make(session.log, lines: 4))
        root.addChild(node: hand(session, fight: fight, send: send))
        return root
    }

    private static func header(_ session: ContractSession, node: Int, fight: FightState) -> Control {
        let machine = fight.machine
        let row = Phosphor.hbox(separation: 24)
        row.addChild(
            node: Phosphor.label(
                "NODE \(node): \(machine.osName) \(machine.osVersion)", color: Phosphor.bright, size: 20))
        row.addChild(node: Phosphor.label("\(machine.orgName)  \(machine.hostname)"))
        row.addChild(node: Phosphor.spacer())
        row.addChild(node: Phosphor.label("TURN \(fight.turn)"))
        row.addChild(
            node: Phosphor.bar(
                "TRACE", value: fight.trace, of: session.state.rules.tuning.trace.max, color: Phosphor.red))
        return Phosphor.panel(row)
    }

    /// Your side: Integrity, Proxy, cycles and RAM, and running daemons.
    private static func player(_ session: ContractSession, fight: FightState) -> Control {
        let box = Phosphor.vbox(separation: 10)
        box.customMinimumSize = Vector2(x: 330, y: 0)
        box.addChild(node: Phosphor.label("YOUR RIG", color: Phosphor.bright, size: 20))
        box.addChild(
            node: Phosphor.bar(
                "INT  ", value: fight.integrity, of: fight.rig.maxIntegrity, color: Phosphor.green))
        let usedRAM = fight.daemons.reduce(0) { $0 + (session.content.card($1.cardID)?.daemon?.ram ?? 0) }
        box.addChild(node: Phosphor.label("PROXY \(fight.proxy)   (BLOCKS ICE DAMAGE THIS TURN)"))
        box.addChild(node: cycles(fight.cycles, of: fight.rig.cycles))
        box.addChild(node: Phosphor.label("RAM \(usedRAM)/\(fight.rig.ram)"))
        if fight.retaliation > 0 { box.addChild(node: Phosphor.label("THORNS \(fight.retaliation)")) }
        let daemons = fight.daemons.compactMap { session.content.card($0.cardID) }
        if !daemons.isEmpty {
            box.addChild(node: Phosphor.label("DAEMONS", color: Phosphor.bright))
            for card in daemons { box.addChild(node: Phosphor.label("  \(card.name)  \(card.headline)", size: 13)) }
        }
        let panel = Phosphor.panel(box)
        panel.sizeFlagsVertical = []
        return panel
    }

    /// Cycles as a row of pips: the fight's energy.
    private static func cycles(_ left: Int, of total: Int) -> Control {
        let row = Phosphor.hbox(separation: 6)
        row.addChild(node: Phosphor.label("CYC"))
        for index in 0..<max(total, left) {
            let pip = Panel()
            pip.customMinimumSize = Vector2(x: 18, y: 18)
            let lit = index < left
            pip.addThemeStyleboxOverride(
                name: "panel",
                stylebox: Phosphor.box(fill: lit ? Phosphor.bright : Phosphor.background, border: Phosphor.green))
            row.addChild(node: pip)
        }
        row.addChild(node: Phosphor.label("\(left)/\(total)"))
        return row
    }

    /// The ICE programs in the middle, as the enemies: each one's next
    /// move over its box, so you can plan around it.
    private static func ice(_ session: ContractSession) -> Control {
        let center = CenterContainer()
        center.sizeFlagsHorizontal = .expandFill
        let row = Phosphor.hbox(separation: 20)
        let telegraphs = session.telegraphs()
        if telegraphs.isEmpty {
            row.addChild(node: Phosphor.label("NO ICE ON THIS MACHINE", color: Phosphor.dim, size: 20))
        }
        for telegraph in telegraphs {
            let name = session.content.iceDefinition(telegraph.iceID)?.name ?? telegraph.iceID.uppercased()
            let column = Phosphor.vbox(separation: 6)
            for intent in telegraph.intents {
                let next = Phosphor.label(intent.label, color: Phosphor.red, size: 18)
                next.horizontalAlignment = .center
                column.addChild(node: next)
            }
            let body = Phosphor.vbox(separation: 4)
            body.customMinimumSize = Vector2(x: 170, y: 150)
            body.alignment = .center
            for line in ["[ICE]", name] {
                let label = Phosphor.label(line, color: Phosphor.amber, size: line == name ? 22 : 14)
                label.horizontalAlignment = .center
                body.addChild(node: label)
            }
            let box = PanelContainer()
            box.addThemeStyleboxOverride(
                name: "panel", stylebox: Phosphor.box(fill: Phosphor.panel, border: Phosphor.amber, width: 2))
            box.addChild(node: body)
            column.addChild(node: box)
            row.addChild(node: column)
        }
        center.addChild(node: row)
        return center
    }

    /// The machine: its security layers top to bottom, the one under
    /// attack marked.
    private static func machine(_ session: ContractSession, fight: FightState) -> Control {
        let box = Phosphor.vbox(separation: 8)
        box.customMinimumSize = Vector2(x: 400, y: 0)
        box.addChild(node: Phosphor.label("SECURITY", color: Phosphor.bright, size: 20))
        let current = fight.currentLayerIndex
        for (index, layer) in fight.machine.layers.enumerated() {
            let marker = index == current ? "> " : "  "
            let color = layer.isBreached ? Phosphor.dim : layer.kind == .kernel ? Phosphor.amber : Phosphor.green
            box.addChild(
                node: Phosphor.bar(
                    marker + layer.kind.label.padding(9), value: max(layer.hp, 0), of: layer.maxHP, color: color,
                    width: 200))
        }
        if let transfer = fight.transfer {
            box.addChild(
                node: Phosphor.bar(
                    "  TRANSFER ", value: transfer.doneMB, of: transfer.totalMB, color: Phosphor.bright, width: 200))
        }
        let weak = fight.revealed ? fight.machine.weak.map(\.label).joined(separator: " ") : "???"
        let resist = fight.revealed ? fight.machine.resist.map(\.label).joined(separator: " ") : "???"
        box.addChild(node: Phosphor.label("WEAK: \(weak)   RESIST: \(resist)", size: 13))

        let panel = Phosphor.panel(box)
        panel.sizeFlagsVertical = []
        return panel
    }

    /// The draw pile, the hand as cards, the discard pile and the turn
    /// buttons.
    private static func hand(
        _ session: ContractSession, fight: FightState, send: @escaping (ContractAction) -> Void
    ) -> Control {
        let row = Phosphor.hbox(separation: 10)
        row.addChild(node: pile("DRAW", fight.drawPile.count))
        let cards = Phosphor.hbox(separation: 10)
        cards.sizeFlagsHorizontal = .expandFill
        cards.alignment = .center
        for (index, instance) in fight.hand.enumerated() {
            guard let card = session.content.card(instance.cardID) else { continue }
            let refusal = session.refusal(forPlaying: index)
            cards.addChild(node: CardView.make(card, refusal: refusal) { send(.fight(.play(handIndex: index))) })
        }
        if fight.hand.isEmpty { cards.addChild(node: Phosphor.label("NO CARDS IN HAND")) }
        row.addChild(node: cards)
        row.addChild(node: pile("DISCARD", fight.discardPile.count))
        let buttons = Phosphor.vbox(separation: 8)
        let end = Phosphor.button("END TURN") { send(.fight(.endTurn)) }
        end.customMinimumSize = Vector2(x: 140, y: 64)
        buttons.addChild(node: end)
        buttons.addChild(node: Phosphor.button("LOGOUT") { send(.fight(.logout)) })
        row.addChild(node: buttons)
        return row
    }

    private static func pile(_ name: String, _ count: Int) -> Control {
        let box = Phosphor.vbox(
            separation: 2,
            [Phosphor.label(name, size: 13), Phosphor.label("\(count)", color: Phosphor.bright, size: 28)])
        box.customMinimumSize = Vector2(x: 70, y: 0)
        box.alignment = .center
        return box
    }
}

extension String {
    /// Pads with spaces to `width` characters, for the monospace columns.
    func padding(_ width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}
