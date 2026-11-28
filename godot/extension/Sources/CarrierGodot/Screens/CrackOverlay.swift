import CarrierCore
import SwiftGodot

/// The dialogs over a crack: the reward between servers, and the end of the
/// run.
enum CrackOverlay {
    /// Take one of the offered cards, remove a card from the deck, or skip.
    /// The next server's profile is shown, so the choice is for that lock.
    static func reward(
        _ play: CrackPlay, cards: [String], next: String, send: @escaping (CrackRunAction) -> Void
    ) -> Control {
        let content = play.content
        let box = Phosphor.vbox(separation: 12)
        box.addChild(node: Phosphor.label("CRACKED. CHOOSE ONE", color: Phosphor.bright, size: 26))
        if let server = content.server(next) {
            let line = "NEXT: \(server.name). " + server.profile
            box.addChild(node: RuleText.make(line, content: content, size: 16, color: Phosphor.amber))
        }
        box.addChild(node: Phosphor.label("TAKE A CARD", size: 16))
        let offers = Phosphor.hbox(separation: 12)
        for (index, id) in cards.enumerated() {
            guard let card = content.card(id) else { continue }
            let refusal = play.engine.rejection(of: .take(index), in: play.state)
            let model = CrackCardView.Model(card: card, cost: play.rules.cost(of: card), refusal: refusal?.label)
            offers.addChild(node: CrackCardView.make(model, content: content) { send(.take(index)) })
        }
        box.addChild(node: offers)

        box.addChild(
            node: Phosphor.label(
                "OR REMOVE A CARD. DECK \(play.state.deck.count)/\(content.run.deckLimit):", size: 16))
        let deck = HFlowContainer()
        deck.addThemeConstantOverride(name: "h_separation", constant: 6)
        deck.addThemeConstantOverride(name: "v_separation", constant: 6)
        deck.customMinimumSize = Vector2(x: 760, y: 0)
        for (index, id) in play.state.deck.enumerated() {
            let card = content.card(id)
            let button = Phosphor.button(card?.label ?? id) { send(.remove(index)) }
            button.tooltipText = "REMOVE: " + (card?.rules ?? "")
            deck.addChild(node: button)
        }
        box.addChild(node: deck)
        box.addChild(node: Phosphor.button("SKIP") { send(.skip) })
        return box
    }

    static func ended(_ play: CrackPlay, again: @escaping () -> Void) -> Control {
        let box = Phosphor.vbox(separation: 12)
        let won = play.state.phase == .won
        let total = play.content.run.servers.count
        let loggedOut = play.crack?.outcome == .loggedOut
        let title = won ? (total > 1 ? "RUN COMPLETE" : "ACCESS GRANTED") : (loggedOut ? "LOGGED OUT" : "NO CARRIER")
        box.addChild(node: Phosphor.label(title, color: won ? Phosphor.bright : Phosphor.red, size: 34))
        box.addChild(node: Phosphor.label("CRACKED \(play.state.round) OF \(total) SERVERS"))
        if let crack = play.crack {
            box.addChild(
                node: Phosphor.label("THE CODE WAS " + crack.code.joined(separator: " "), color: Phosphor.amber))
        }
        box.addChild(node: Phosphor.label("SEED \(Seed.display(play.state.seed))", color: Phosphor.dim))
        box.addChild(node: Phosphor.button("NEW RUN", action: again))
        return box
    }
}
