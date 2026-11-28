import CarrierCore
import SwiftGodot

/// The machine's security layers, outermost first, with the one under
/// attack marked, a TRANSFER bar on a stealth job, and what is weak and
/// resisted once probed.
enum LayerStack {
    static func make(
        layers: [SecurityLayer], current: Int?, transfer: TransferProgress?, weak: [ExploitTag]?,
        resist: [ExploitTag]?
    ) -> Control {
        let box = Phosphor.vbox(separation: 8)
        box.customMinimumSize = Vector2(x: 400, y: 0)
        box.addChild(node: Phosphor.label("SECURITY", color: Phosphor.bright, size: 20))
        for (index, layer) in layers.enumerated() {
            let marker = index == current ? "> " : "  "
            let color = layer.isBreached ? Phosphor.dim : layer.kind == .kernel ? Phosphor.amber : Phosphor.green
            box.addChild(
                node: Phosphor.bar(
                    marker + layer.kind.label.padding(9), value: max(layer.hp, 0), of: layer.maxHP, color: color,
                    width: 200))
        }
        if let transfer {
            box.addChild(
                node: Phosphor.bar(
                    "  TRANSFER ", value: transfer.doneMB, of: transfer.totalMB, color: Phosphor.bright, width: 200))
        }
        let weakText = weak.map { $0.map(\.label).joined(separator: " ") } ?? "???"
        let resistText = resist.map { $0.map(\.label).joined(separator: " ") } ?? "???"
        box.addChild(node: Phosphor.label("WEAK: \(weakText)   RESIST: \(resistText)", size: 13))
        let panel = Phosphor.panel(box)
        panel.sizeFlagsVertical = []
        return panel
    }
}
