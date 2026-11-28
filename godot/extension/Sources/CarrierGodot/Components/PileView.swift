import SwiftGodot

/// A card pile beside the hand: its name and how many cards are in it.
enum PileView {
    static func make(_ name: String, count: Int) -> Control {
        let box = Phosphor.vbox(
            separation: 2,
            [Phosphor.label(name, size: 13), Phosphor.label("\(count)", color: Phosphor.bright, size: 28)])
        box.customMinimumSize = Vector2(x: 70, y: 0)
        box.alignment = .center
        return box
    }
}
