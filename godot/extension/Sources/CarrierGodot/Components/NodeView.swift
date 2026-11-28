import CarrierCore
import SwiftGodot

/// One node on the map. The border says whether you can attack it, the
/// color says who owns it, and the text is its number, its type letter
/// and its type.
enum NodeView {
    /// Everything a node box shows, so a gallery can draw any state.
    struct Model {
        var index: Int
        /// `E`, `R`, ... or `?` when not scanned, `$` for the file.
        var letter: String
        /// `REPAIR`, or `UNKNOWN` when not scanned.
        var name: String
        var owner: NodeOwner
        var accessed = false
        var attackable = false
        var contested = false
        var tooltip = ""
    }

    static var size: Vector2 { Vector2(x: 132, y: 80) }

    static func make(_ model: Model) -> Button {
        let button = Button()
        button.text = "\(model.index)\(model.letter)\(model.contested ? "!" : "")\n\(model.name)"
        let color: Color =
            switch model.owner {
            case .player: Phosphor.bright
            case .sysop: Phosphor.amber
            case .neutral: model.accessed ? Phosphor.bright : Phosphor.green
            }
        let fill = model.owner == .player ? Phosphor.dim : Phosphor.panel
        let border = model.attackable ? Phosphor.bright : color
        let width: Int32 = model.attackable ? 3 : model.owner == .player ? 2 : 1
        button.addThemeStyleboxOverride(
            name: "normal", stylebox: Phosphor.box(fill: fill, border: border, width: width))
        button.addThemeStyleboxOverride(
            name: "hover", stylebox: Phosphor.box(fill: Phosphor.dim, border: Phosphor.bright, width: 3))
        button.addThemeColorOverride(name: "font_color", color: color)
        button.addThemeFontSizeOverride(name: "font_size", fontSize: 19)
        button.customMinimumSize = size
        button.tooltipText = model.tooltip
        return button
    }

    /// The model for a node in a running contract.
    static func model(_ node: NetworkNode, session: ContractSession, attackable: Bool) -> Model {
        let state = session.state
        let isTarget = node.index == state.targetNode && !state.hasFile
        let scanned = node.visibility == .scanned
        var lines: [String] = []
        if scanned {
            lines.append("NODE \(node.index) \(node.type.label), \(node.owner.rawValue.uppercased())")
            lines.append(session.meaning(of: node.type))
            lines.append("\(node.machine.osName) \(node.machine.osVersion) \(node.machine.hostname)")
        } else {
            lines.append("NODE \(node.index): NOT SCANNED. CLICK TO SCAN (+ALERT).")
        }
        if attackable { lines.append("CLICK TO ATTACK.") }
        if node.accessed { lines.append("ACCESSED: YOU HAVE A WAY IN.") }
        return Model(
            index: node.index, letter: isTarget ? "$" : scanned ? node.type.mapLetter : "?",
            name: scanned ? node.type.label : "UNKNOWN", owner: node.owner, accessed: node.accessed,
            attackable: attackable, contested: node.contested, tooltip: lines.joined(separator: "\n"))
    }
}
