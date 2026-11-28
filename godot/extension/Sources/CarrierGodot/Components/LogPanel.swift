import SwiftGodot

/// The last lines of the event log.
enum LogPanel {
    static func make(_ log: [String], lines: Int) -> Control {
        let box = Phosphor.vbox(separation: 0)
        let shown = log.suffix(lines)
        for (offset, line) in shown.enumerated() {
            let last = offset == shown.count - 1
            box.addChild(node: Phosphor.label("] " + line, color: last ? Phosphor.bright : Phosphor.dim, size: 14))
        }
        box.customMinimumSize = Vector2(x: 0, y: Float(lines) * 19)
        return Phosphor.panel(box)
    }
}
