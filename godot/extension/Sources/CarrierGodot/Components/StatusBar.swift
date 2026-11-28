import CarrierCore
import SwiftGodot

/// The contract's status across the top of the map.
enum StatusBar {
    static func make(_ state: ContractState) -> Control {
        let tuning = state.rules.tuning
        let row = Phosphor.hbox(separation: 24)
        row.addChild(node: Phosphor.label(state.network.orgName, color: Phosphor.bright, size: 20))
        row.addChild(node: Phosphor.label("TICK \(state.tick)"))
        row.addChild(node: Phosphor.label("SEED \(Seed.display(state.seed))", color: Phosphor.dim))
        row.addChild(node: Phosphor.spacer())
        row.addChild(node: Phosphor.bar("TRACE", value: state.trace, of: tuning.trace.max, color: Phosphor.red))
        if state.rules.isOn(.alert) {
            row.addChild(
                node: Phosphor.bar(
                    "ALERT \(state.alertState.label)", value: state.alert, of: tuning.network.alert.max,
                    color: Phosphor.amber, width: 100))
        }
        row.addChild(
            node: Phosphor.bar(
                "INT", value: state.integrity, of: state.rig.maxIntegrity, color: Phosphor.green, width: 100))
        return Phosphor.panel(row)
    }
}
