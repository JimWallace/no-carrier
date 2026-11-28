import CarrierCore
import SwiftGodot

/// The choice screens that sit over the map or a battle: GHOST or CLAIM,
/// the loot, a DATA upgrade, and the end of the contract.
enum Overlay {
    /// `page` with `dialog` centered over it on a dark veil.
    static func over(_ page: Control, _ dialog: Control) -> Control {
        let holder = Control()
        holder.sizeFlagsHorizontal = .expandFill
        holder.sizeFlagsVertical = .expandFill
        page.setAnchorsAndOffsetsPreset(.fullRect)
        holder.addChild(node: page)
        let veil = ColorRect()
        veil.color = Color(r: 0, g: 0, b: 0, a: 0.72)
        veil.setAnchorsAndOffsetsPreset(.fullRect)
        holder.addChild(node: veil)
        let center = CenterContainer()
        center.setAnchorsAndOffsetsPreset(.fullRect)
        center.addChild(node: Phosphor.panel(dialog))
        holder.addChild(node: center)
        return holder
    }

    static func accessChoice(node: Int, send: @escaping (ContractAction) -> Void) -> Control {
        let box = Phosphor.vbox(separation: 12)
        box.addChild(node: Phosphor.label("AUTH BREACHED ON NODE \(node)", color: Phosphor.bright, size: 24))
        box.addChild(
            node: Phosphor.hbox(
                separation: 16,
                [
                    choice("P0WN IT", "FIGHT ON THROUGH THE KERNEL.\nCAPTURE THE NODE AND TAKE LOOT.") { send(.claim) },
                    choice("GHOST IT", "LEAVE NOW WITH ACCESS.\nQUIET: THE SYSOP NOTICES LESS.") { send(.ghost) },
                ]))
        return box
    }

    static func reward(
        _ session: ContractSession, choices: [String], send: @escaping (ContractAction) -> Void
    ) -> Control {
        let box = Phosphor.vbox(separation: 12)
        box.addChild(node: Phosphor.label("LOOT: TAKE ONE CARD", color: Phosphor.bright, size: 24))
        let cards = Phosphor.hbox(separation: 12)
        for (index, id) in choices.enumerated() {
            guard let card = session.content.card(id) else { continue }
            cards.addChild(node: CardView.make(card, refusal: nil) { send(.takeReward(choice: index, replacing: nil)) })
        }
        box.addChild(node: cards)
        box.addChild(node: Phosphor.button("SKIP") { send(.skipReward) })
        return box
    }

    static func upgrade(_ choices: [RigUpgrade], send: @escaping (ContractAction) -> Void) -> Control {
        let box = Phosphor.vbox(separation: 12)
        box.addChild(node: Phosphor.label("DATA: CHOOSE AN UPGRADE", color: Phosphor.bright, size: 24))
        for (index, upgrade) in choices.enumerated() {
            box.addChild(node: Phosphor.button(upgrade.label) { send(.chooseUpgrade(choice: index)) })
        }
        return box
    }

    static func ended(_ session: ContractSession, outcome: ContractOutcome, again: @escaping () -> Void) -> Control {
        let box = Phosphor.vbox(separation: 12)
        let title = outcome.title(win: session.state.objective.win)
        box.addChild(node: Phosphor.label(title, color: outcome == .won ? Phosphor.bright : Phosphor.red, size: 32))
        if let payout = session.state.payout { box.addChild(node: Phosphor.label("PAYOUT: \(payout.label)")) }
        box.addChild(node: Phosphor.label("SEED \(Seed.display(session.state.seed))", color: Phosphor.dim))
        box.addChild(node: Phosphor.button("NEW CONTRACT", action: again))
        return box
    }

    private static func choice(_ title: String, _ detail: String, action: @escaping () -> Void) -> Button {
        let button = Phosphor.button(title + "\n\n" + detail, action: action)
        button.customMinimumSize = Vector2(x: 300, y: 130)
        return button
    }
}
