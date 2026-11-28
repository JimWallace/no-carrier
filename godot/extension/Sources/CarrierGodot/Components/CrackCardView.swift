import CarrierCore
import SwiftGodot

/// One crack card: its cost, its name (a symbol card shows its symbol
/// large), and its rules with keywords in bold. Click it to pick it (a card
/// played on a slot) or to run it (a card played on its own).
enum CrackCardView {
    static var size: Vector2 { Vector2(x: 150, y: 196) }

    struct Model {
        var card: CrackCard
        var cost: Int
        var selected = false
        /// Why it cannot run now, or nil.
        var refusal: String?
    }

    static func make(_ model: Model, content: CrackContent, click: @escaping () -> Void) -> Control {
        let card = model.card
        let usable = model.refusal == nil
        let button = Button()
        button.customMinimumSize = size
        button.mouseDefaultCursorShape = .pointingHand
        let border = model.selected ? Phosphor.amber : (usable ? Phosphor.green : Phosphor.dim)
        let width: Int32 = model.selected ? 3 : 2
        button.addThemeStyleboxOverride(
            name: "normal", stylebox: Phosphor.box(fill: Phosphor.panel, border: border, width: width))
        button.addThemeStyleboxOverride(
            name: "hover", stylebox: Phosphor.box(fill: Phosphor.panel, border: Phosphor.bright, width: 3))
        button.addThemeStyleboxOverride(
            name: "pressed", stylebox: Phosphor.box(fill: Phosphor.panel, border: Phosphor.amber, width: 3))
        button.pressed.connect(click)

        let margin = MarginContainer()
        margin.setAnchorsAndOffsetsPreset(.fullRect)
        for side in ["left", "right", "top", "bottom"] {
            margin.addThemeConstantOverride(name: StringName("margin_\(side)"), constant: 8)
        }
        margin.mouseFilter = .pass
        let face = Phosphor.vbox(separation: 4)
        face.mouseFilter = .pass

        let top = Phosphor.hbox(separation: 8)
        top.mouseFilter = .pass
        let cost = Phosphor.label("\(model.cost)", color: Phosphor.background, size: 16)
        cost.horizontalAlignment = .center
        cost.customMinimumSize = Vector2(x: 24, y: 24)
        cost.addThemeStyleboxOverride(
            name: "normal",
            stylebox: Phosphor.box(fill: usable ? Phosphor.bright : Phosphor.dim, border: Phosphor.bright, padding: 1))
        top.addChild(node: cost)
        top.addChild(node: Phosphor.label(card.kind.playLabel, color: Phosphor.dim, size: 11))
        face.addChild(node: top)

        let isSymbol = card.kind == .symbol
        let name = Phosphor.label(
            card.label, color: usable ? Phosphor.bright : Phosphor.green, size: isSymbol ? 54 : 20)
        name.horizontalAlignment = .center
        face.addChild(node: name)
        if !isSymbol {
            face.addChild(node: RuleText.make(card.rules, content: content))
        }
        let spacer = Phosphor.spacer()
        spacer.mouseFilter = .pass
        face.addChild(node: spacer)
        if let refusal = model.refusal {
            let line = Phosphor.label(refusal, color: Phosphor.red, size: 12)
            line.autowrapMode = .wordSmart
            face.addChild(node: line)
        }
        margin.addChild(node: face)
        button.addChild(node: margin)
        return button
    }
}
