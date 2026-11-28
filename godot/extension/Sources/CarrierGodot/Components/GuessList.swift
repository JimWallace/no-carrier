import CarrierCore
import SwiftGodot

/// Every guess so far, one a row: its number, its symbols, and what the
/// server said. Per-slot marks sit under their symbols, colored.
enum GuessList {
    static func make(_ guesses: [CrackGuess], legend: String) -> Control {
        let box = Phosphor.vbox(separation: 6)
        box.addChild(node: Phosphor.label("GUESSES", color: Phosphor.bright, size: 18))
        if guesses.isEmpty {
            box.addChild(node: Phosphor.label("NONE YET", color: Phosphor.dim))
        }
        for (index, guess) in guesses.enumerated() {
            let row = Phosphor.hbox(separation: 10)
            row.addChild(node: Phosphor.label((index < 9 ? " " : "") + "\(index + 1)", color: Phosphor.dim, size: 16))
            let symbols = Phosphor.hbox(separation: 4)
            for (slot, symbol) in guess.symbols.enumerated() {
                symbols.addChild(node: cell(symbol ?? ".", mark: guess.feedback.marks?[slot]))
            }
            row.addChild(node: symbols)
            if guess.feedback.marks == nil {
                row.addChild(node: counts(guess.feedback))
            }
            box.addChild(node: row)
        }
        box.addChild(node: Phosphor.spacer())
        let note = Phosphor.label(legend, color: Phosphor.dim, size: 12)
        note.autowrapMode = .wordSmart
        box.addChild(node: note)
        box.customMinimumSize = Vector2(x: 330, y: 0)
        return Phosphor.panel(box)
    }

    /// A symbol in a small box; with a mark, the box shows it: bright for a
    /// hit, amber for near, dim for a miss.
    private static func cell(_ symbol: String, mark: CrackMark?) -> Control {
        let color: Color
        switch mark {
        case .hit: color = Phosphor.bright
        case .near: color = Phosphor.amber
        case .miss: color = Phosphor.dim
        case nil: color = Phosphor.green
        }
        let label = Phosphor.label(symbol, color: mark == .hit ? Phosphor.background : color, size: 22)
        label.horizontalAlignment = .center
        label.customMinimumSize = Vector2(x: 34, y: 34)
        let fill = mark == .hit ? Phosphor.bright : Phosphor.background
        label.addThemeStyleboxOverride(name: "normal", stylebox: Phosphor.box(fill: fill, border: color, padding: 2))
        if let mark { label.tooltipText = mark.label }
        label.mouseFilter = .stop
        return label
    }

    private static func counts(_ feedback: CrackFeedback) -> Control {
        let row = Phosphor.hbox(separation: 8)
        row.addChild(node: Phosphor.label("\(feedback.hits) HIT", color: Phosphor.bright, size: 16))
        if let near = feedback.near {
            row.addChild(node: Phosphor.label("\(near) NEAR", color: Phosphor.amber, size: 16))
        }
        return row
    }
}
