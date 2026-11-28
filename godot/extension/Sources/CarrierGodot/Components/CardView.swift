import CarrierCore
import SwiftGodot

/// One card in hand: cost, name and type on top, then every ability in
/// words, and why it cannot run when it cannot.
enum CardView {
    static func make(_ card: CardDefinition, refusal: RejectReason?, play: @escaping () -> Void) -> Control {
        let playable = refusal == nil
        // The card is a panel that grows to fit its text, with a flat button
        // over the whole of it for the click and the hover border.
        let holder = PanelContainer()
        holder.customMinimumSize = BattleView.cardSize
        holder.tooltipText = card.abilities.map(\.long).joined(separator: "\n")
        let border = playable ? Phosphor.green : Phosphor.dim
        holder.addThemeStyleboxOverride(
            name: "panel", stylebox: Phosphor.box(fill: Phosphor.panel, border: border, width: 2, padding: 8))

        let face = Phosphor.vbox(separation: 4)
        let top = Phosphor.hbox(separation: 8)
        let cost = Phosphor.label(card.cost.label, color: Phosphor.background, size: 18)
        cost.horizontalAlignment = .center
        cost.customMinimumSize = Vector2(x: 26, y: 26)
        cost.addThemeStyleboxOverride(
            name: "normal",
            stylebox: Phosphor.box(fill: playable ? Phosphor.bright : Phosphor.dim, border: Phosphor.bright, padding: 1)
        )
        top.addChild(node: cost)
        let name = Phosphor.label(card.name, color: playable ? Phosphor.bright : Phosphor.green)
        name.clipText = true
        name.sizeFlagsHorizontal = .expandFill
        top.addChild(node: name)
        face.addChild(node: top)
        face.addChild(node: Phosphor.label(card.type.label + tags(card), color: Phosphor.dim, size: 12))

        let headline = Phosphor.label(card.headline, color: Phosphor.bright, size: 18)
        headline.autowrapMode = .wordSmart
        face.addChild(node: headline)
        for ability in card.abilities {
            let line = Phosphor.label(ability.long, size: 12)
            line.autowrapMode = .wordSmart
            face.addChild(node: line)
        }
        face.addChild(node: Phosphor.spacer())
        if let refusal {
            face.addChild(node: Phosphor.label(refusal.shortLabel, color: Phosphor.red, size: 14))
        }
        holder.addChild(node: face)

        let button = Button()
        button.flat = true
        button.mouseDefaultCursorShape = .pointingHand
        button.addThemeStyleboxOverride(name: "normal", stylebox: StyleBoxEmpty())
        button.addThemeStyleboxOverride(name: "pressed", stylebox: StyleBoxEmpty())
        let hover = Phosphor.box(fill: Color(r: 0, g: 0, b: 0, a: 0), border: Phosphor.bright, width: 3)
        hover.setExpandMarginAll(size: 8)
        button.addThemeStyleboxOverride(name: "hover", stylebox: hover)
        button.pressed.connect(play)
        holder.addChild(node: button)
        return holder
    }

    private static func tags(_ card: CardDefinition) -> String {
        card.tags.isEmpty ? "" : "  " + card.tags.map(\.label).joined(separator: " ")
    }
}
