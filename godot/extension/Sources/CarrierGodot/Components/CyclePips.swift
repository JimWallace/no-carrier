import SwiftGodot

/// Cycles as a row of pips, lit for each one left: the fight's energy.
enum CyclePips {
    static func make(left: Int, total: Int) -> Control {
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
}
