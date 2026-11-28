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
        arena.addChild(node: machine(fight))
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

    private static func player(_ session: ContractSession, fight: FightState) -> Control {
        let daemons = fight.daemons.compactMap { session.content.card($0.cardID) }
        return RigPanel.make(
            RigPanel.Model(
                integrity: fight.integrity, maxIntegrity: fight.rig.maxIntegrity, proxy: fight.proxy,
                cycles: fight.cycles, maxCycles: fight.rig.cycles,
                ramUsed: daemons.reduce(0) { $0 + ($1.daemon?.ram ?? 0) }, ram: fight.rig.ram,
                thorns: fight.retaliation, daemons: daemons.map { ($0.name, $0.headline) }))
    }

    /// The ICE programs in the middle, as the enemies.
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
            row.addChild(node: ICEView.make(name: name, intents: telegraph.intents.map(\.label)))
        }
        center.addChild(node: row)
        return center
    }

    private static func machine(_ fight: FightState) -> Control {
        LayerStack.make(
            layers: fight.machine.layers, current: fight.currentLayerIndex, transfer: fight.transfer,
            weak: fight.revealed ? fight.machine.weak : nil, resist: fight.revealed ? fight.machine.resist : nil)
    }

    /// The draw pile, the hand as cards, the discard pile and the turn
    /// buttons.
    private static func hand(
        _ session: ContractSession, fight: FightState, send: @escaping (ContractAction) -> Void
    ) -> Control {
        let row = Phosphor.hbox(separation: 10)
        row.addChild(node: PileView.make("DRAW", count: fight.drawPile.count))
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
        row.addChild(node: PileView.make("DISCARD", count: fight.discardPile.count))
        let buttons = Phosphor.vbox(separation: 8)
        let end = Phosphor.button("END TURN") { send(.fight(.endTurn)) }
        end.customMinimumSize = Vector2(x: 140, y: 64)
        buttons.addChild(node: end)
        buttons.addChild(node: Phosphor.button("LOGOUT") { send(.fight(.logout)) })
        row.addChild(node: buttons)
        return row
    }
}
