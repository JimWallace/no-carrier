import SwiftGodot

/// Your side of a fight: Integrity, Proxy, cycles, RAM, Thorns and the
/// daemons running.
enum RigPanel {
    struct Model {
        var integrity: Int
        var maxIntegrity: Int
        var proxy: Int
        var cycles: Int
        var maxCycles: Int
        var ramUsed: Int
        var ram: Int
        var thorns = 0
        /// Each running daemon's name and what it does.
        var daemons: [(name: String, headline: String)] = []
    }

    static func make(_ model: Model) -> Control {
        let box = Phosphor.vbox(separation: 10)
        box.customMinimumSize = Vector2(x: 330, y: 0)
        box.addChild(node: Phosphor.label("YOUR RIG", color: Phosphor.bright, size: 20))
        box.addChild(
            node: Phosphor.bar("INT  ", value: model.integrity, of: model.maxIntegrity, color: Phosphor.green))
        box.addChild(node: Phosphor.label("PROXY \(model.proxy)   (BLOCKS ICE DAMAGE THIS TURN)"))
        box.addChild(node: CyclePips.make(left: model.cycles, total: model.maxCycles))
        box.addChild(node: Phosphor.label("RAM \(model.ramUsed)/\(model.ram)"))
        if model.thorns > 0 { box.addChild(node: Phosphor.label("THORNS \(model.thorns)")) }
        if !model.daemons.isEmpty {
            box.addChild(node: Phosphor.label("DAEMONS", color: Phosphor.bright))
            for daemon in model.daemons {
                box.addChild(node: Phosphor.label("  \(daemon.name)  \(daemon.headline)", size: 13))
            }
        }
        let panel = Phosphor.panel(box)
        panel.sizeFlagsVertical = []
        return panel
    }
}
