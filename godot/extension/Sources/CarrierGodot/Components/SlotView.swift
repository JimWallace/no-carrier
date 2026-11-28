import SwiftGodot

/// One slot of the board: its number, what the code is known to hold there,
/// the symbol on it, and for a dial the arrows that turn it. Click it to
/// play the picked card there, or to swap.
enum SlotView {
    static var size: Vector2 { Vector2(x: 116, y: 132) }

    struct Model {
        var number: Int
        var symbol: String?
        var isDial = false
        var isLocked = false
        /// The code's symbol here, from a probe.
        var known: String?
        var selected = false
        /// A card is picked and could go here.
        var target = false
    }

    static func make(
        _ model: Model, click: @escaping () -> Void, turn: ((Int) -> Void)? = nil
    ) -> Control {
        let column = Phosphor.vbox(separation: 4)
        let known = Phosphor.label(model.known.map { "IS \($0)" } ?? " ", color: Phosphor.amber, size: 14)
        known.horizontalAlignment = .center
        column.addChild(node: known)

        let button = Button()
        button.customMinimumSize = size
        button.mouseDefaultCursorShape = .pointingHand
        let border =
            model.selected
            ? Phosphor.amber : (model.target ? Phosphor.bright : (model.symbol == nil ? Phosphor.dim : Phosphor.green))
        let fill = model.symbol == nil ? Phosphor.background : Phosphor.panel
        button.addThemeStyleboxOverride(
            name: "normal",
            stylebox: Phosphor.box(fill: fill, border: border, width: model.selected || model.target ? 3 : 2))
        button.addThemeStyleboxOverride(
            name: "hover", stylebox: Phosphor.box(fill: fill, border: Phosphor.bright, width: 3))
        button.text = model.symbol ?? "."
        button.addThemeFontSizeOverride(name: "font_size", fontSize: 60)
        button.addThemeColorOverride(name: "font_color", color: model.symbol == nil ? Phosphor.dim : Phosphor.bright)
        button.pressed.connect(click)
        var tips: [String] = []
        if model.isDial { tips.append("DIAL: TURN IT WITH THE ARROWS.") }
        if model.isLocked { tips.append("LOCKED: SCRAMBLE CANNOT MOVE IT.") }
        button.tooltipText = tips.joined(separator: "\n")
        column.addChild(node: button)

        let foot = Phosphor.hbox(separation: 4)
        foot.alignment = .center
        if model.isDial, let turn {
            foot.addChild(node: Phosphor.button("<") { turn(-1) })
        }
        let tag = "\(model.number)" + (model.isDial ? " DIAL" : "") + (model.isLocked ? " LOCK" : "")
        foot.addChild(node: Phosphor.label(tag, color: model.isLocked ? Phosphor.amber : Phosphor.dim, size: 13))
        if model.isDial, let turn {
            foot.addChild(node: Phosphor.button(">") { turn(1) })
        }
        column.addChild(node: foot)
        return column
    }
}
