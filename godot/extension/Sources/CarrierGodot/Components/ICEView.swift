import SwiftGodot

/// One ICE program in a fight, drawn as an enemy: its next moves above
/// its box, in red, so you can plan around them.
enum ICEView {
    static func make(name: String, intents: [String]) -> Control {
        let column = Phosphor.vbox(separation: 6)
        for intent in intents {
            let next = Phosphor.label(intent, color: Phosphor.red, size: 18)
            next.horizontalAlignment = .center
            column.addChild(node: next)
        }
        let body = Phosphor.vbox(separation: 4)
        body.customMinimumSize = Vector2(x: 170, y: 150)
        body.alignment = .center
        for (line, size) in [("[ICE]", Int32(14)), (name, 22)] {
            let label = Phosphor.label(line, color: Phosphor.amber, size: size)
            label.horizontalAlignment = .center
            body.addChild(node: label)
        }
        let box = PanelContainer()
        box.addThemeStyleboxOverride(
            name: "panel", stylebox: Phosphor.box(fill: Phosphor.panel, border: Phosphor.amber, width: 2))
        box.addChild(node: body)
        column.addChild(node: box)
        return column
    }
}
