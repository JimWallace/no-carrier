import CarrierCore
import SwiftGodot

/// The network map: the nodes on their grid with the links between them,
/// the contract's status above, and the sysop, the key and the actions
/// beside. Click a highlighted node to attack it.
enum MapView {
    static var cell: Vector2 { Vector2(x: 196, y: 150) }
    static var nodeSize: Vector2 { Vector2(x: 132, y: 80) }

    static func make(_ session: ContractSession, send: @escaping (ContractAction) -> Void) -> Control {
        let state = session.state
        let root = Phosphor.vbox(separation: 10)
        root.addChild(node: StatusBar.make(state))

        let middle = Phosphor.hbox(separation: 16)
        middle.sizeFlagsVertical = .expandFill
        middle.addChild(node: Phosphor.panel(network(session, send: send)))
        middle.addChild(node: side(session, send: send))
        root.addChild(node: middle)
        root.addChild(node: LogPanel.make(session.log, lines: 6))
        return root
    }

    private static func network(_ session: ContractSession, send: @escaping (ContractAction) -> Void) -> Control {
        let state = session.state
        let canvas = Control()
        canvas.sizeFlagsHorizontal = .expandFill
        canvas.sizeFlagsVertical = .expandFill
        canvas.customMinimumSize = Vector2(x: 5 * cell.x, y: 4 * cell.y)
        let hint = Phosphor.label("CLICK A BRIGHT NODE TO ATTACK IT. HOVER FOR DETAILS.", color: Phosphor.dim, size: 14)
        hint.setPosition(Vector2(x: 32, y: 12))
        canvas.addChild(node: hint)
        let nodes = state.network.nodes
        let origin = Vector2(x: 32, y: 48)
        func center(_ node: NetworkNode) -> Vector2 {
            origin + Vector2(x: Float(node.column) * cell.x, y: Float(node.row) * cell.y) + nodeSize / 2
        }
        for link in state.network.links where link.count == 2 {
            let a = nodes[link[0]]
            let b = nodes[link[1]]
            guard a.visibility != .hidden, b.visibility != .hidden else { continue }
            let line = Line2D()
            line.addPoint(position: center(a))
            line.addPoint(position: center(b))
            line.width = 3
            line.defaultColor = Phosphor.dim
            canvas.addChild(node: line)
        }
        let attackable = Set(state.network.attackable)
        for node in nodes where node.visibility != .hidden {
            let button = nodeButton(node, session: session, attackable: attackable.contains(node.index))
            button.setPosition(origin + Vector2(x: Float(node.column) * cell.x, y: Float(node.row) * cell.y))
            button.setSize(nodeSize)
            let index = node.index
            if attackable.contains(index) {
                button.pressed.connect { send(.attack(node: index)) }
            } else if node.isFoothold && node.contested {
                button.pressed.connect { send(.reinforce(node: index)) }
            } else if node.visibility == .detected {
                button.pressed.connect { send(.scan(node: index)) }
            }
            canvas.addChild(node: button)
        }
        return canvas
    }

    private static func nodeButton(_ node: NetworkNode, session: ContractSession, attackable: Bool) -> Button {
        let state = session.state
        let isTarget = node.index == state.targetNode && !state.hasFile
        let scanned = node.visibility == .scanned
        let letter = isTarget ? "$" : scanned ? node.type.mapLetter : "?"
        let name = scanned ? node.type.label : "UNKNOWN"
        let button = Button()
        button.text = "\(node.index)\(letter)\(node.contested ? "!" : "")\n\(name)"
        let color: Color =
            switch node.owner {
            case .player: Phosphor.bright
            case .sysop: Phosphor.amber
            case .neutral: node.accessed ? Phosphor.bright : Phosphor.green
            }
        let fill = node.owner == .player ? Phosphor.dim : Phosphor.panel
        let border = attackable ? Phosphor.bright : color
        let width: Int32 = attackable ? 3 : node.owner == .player ? 2 : 1
        button.addThemeStyleboxOverride(
            name: "normal", stylebox: Phosphor.box(fill: fill, border: border, width: width))
        button.addThemeStyleboxOverride(
            name: "hover", stylebox: Phosphor.box(fill: Phosphor.dim, border: Phosphor.bright, width: 3))
        button.addThemeColorOverride(name: "font_color", color: color)
        button.addThemeFontSizeOverride(name: "font_size", fontSize: 19)
        button.tooltipText = tooltip(node, session: session, attackable: attackable)
        return button
    }

    private static func tooltip(_ node: NetworkNode, session: ContractSession, attackable: Bool) -> String {
        var lines: [String] = []
        if node.visibility == .scanned {
            lines.append("NODE \(node.index) \(node.type.label), \(node.owner.rawValue.uppercased())")
            lines.append(session.meaning(of: node.type))
            lines.append("\(node.machine.osName) \(node.machine.osVersion) \(node.machine.hostname)")
        } else {
            lines.append("NODE \(node.index): NOT SCANNED. CLICK TO SCAN (+ALERT).")
        }
        if attackable { lines.append("CLICK TO ATTACK.") }
        if node.accessed { lines.append("ACCESSED: YOU HAVE A WAY IN.") }
        return lines.joined(separator: "\n")
    }

    private static func side(_ session: ContractSession, send: @escaping (ContractAction) -> Void) -> Control {
        let state = session.state
        let box = Phosphor.vbox(separation: 8)
        box.customMinimumSize = Vector2(x: 330, y: 0)
        let sysop =
            state.sysopIntent.map { "SYSOP NEXT: \($0.label(content: session.content))" }
            ?? (state.alertState == .dormant ? "SYSOP: DORMANT" : "SYSOP NEXT: -")
        let sysopLabel = Phosphor.label(sysop, color: Phosphor.amber)
        sysopLabel.autowrapMode = .wordSmart
        box.addChild(node: Phosphor.panel(sysopLabel))

        let key = Phosphor.vbox(separation: 2, [Phosphor.label("MAP KEY", color: Phosphor.bright)])
        for type in NodeType.allCases {
            let line = Phosphor.label(
                "\(type.mapLetter) \(session.meaning(of: type))", size: 13)
            line.autowrapMode = .wordSmart
            key.addChild(node: line)
        }
        key.addChild(node: Phosphor.label("? NOT SCANNED YET. ! CONTESTED", size: 13))
        key.addChild(node: Phosphor.label("BRIGHT BORDER: YOU CAN ATTACK IT", size: 13))
        key.addChild(node: Phosphor.label("AMBER: THE SYSOP OWNS IT", color: Phosphor.amber, size: 13))
        box.addChild(node: Phosphor.panel(key))

        let deck = Phosphor.vbox(
            separation: 2, [Phosphor.label("DECK \(state.deck.count)/\(state.storage)", color: Phosphor.bright)])
        for (cardID, count) in grouped(state.deck) {
            guard let card = session.content.card(cardID) else { continue }
            deck.addChild(node: Phosphor.label("\(count)x \(card.name)  \(card.headline)", size: 13))
        }
        box.addChild(node: Phosphor.panel(deck))
        box.addChild(node: Phosphor.spacer())
        let actions = Phosphor.hbox(separation: 8)
        actions.addChild(node: Phosphor.button("WAIT") { send(.wait) })
        actions.addChild(node: Phosphor.button("JACK OUT") { send(.jackOut) })
        box.addChild(node: actions)
        return box
    }

    /// The deck's card IDs with their counts, in first-seen order.
    static func grouped(_ ids: [String]) -> [(String, Int)] {
        var groups: [(String, Int)] = []
        for id in ids {
            if let index = groups.firstIndex(where: { $0.0 == id }) {
                groups[index].1 += 1
            } else {
                groups.append((id, 1))
            }
        }
        return groups
    }
}
