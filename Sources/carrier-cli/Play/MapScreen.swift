import CarrierCore

/// The network map and the contract's status, in 40 columns.
struct MapScreen {
    let state: ContractState
    let content: ContentPack
    let style: Phosphor

    /// Lines above the log: status, map, key and the sysop's next move.
    func top() -> [String] {
        status() + grid() + [key()] + Columns.wrap(sysopLine())
    }

    /// The org, the tick, Trace and the rig.
    func status() -> [String] {
        let traceMax = state.rules.tuning.trace.max
        let traceText = "TRACE " + Columns.bar(state.trace, of: traceMax, cells: 20) + " \(state.trace)"
        let title = Columns.spread(String(state.network.orgName.prefix(28)), "TICK \(state.tick)")
        let alertTuning = state.rules.tuning.network.alert
        let alertText =
            state.rules.isOn(.alert)
            ? "ALERT " + Columns.bar(state.alert, of: alertTuning.max, cells: 10)
                + " \(state.alert) \(state.alertState.label)"
            : "ALERT OFF: SYSOP \(state.alertState.label)"
        return [
            style.inverse(title),
            state.trace * 4 >= traceMax * 3 ? style.blink(traceText) : traceText,
            state.alertState == .active ? style.bright(alertText) : alertText,
            "INT \(state.integrity)/\(state.rig.maxIntegrity) DECK \(state.deck.count)/\(state.storage)"
                + " CYC \(state.rig.cycles) RAM \(state.rig.ram)",
        ] + fileLine()
    }

    /// The stealth job's state, when it has a TARGET.
    private func fileLine() -> [String] {
        guard let target = state.targetNode else { return [] }
        if state.hasFile { return [style.bright("FILE: YOURS (\(state.fileMB) MB). JACK OUT.")] }
        return ["FILE: \(state.fileMB) MB ON NODE \(target)"]
    }

    /// Nodes on a 5 by 4 grid, 7 columns per cell. A node is its number and
    /// type letter in brackets that show the owner: `<0E>` yours, `{6X}` the
    /// sysop's, `[3V]` free. `!` marks a node under CONTEST.
    func grid() -> [String] {
        let nodes = state.network.nodes
        let rows = (nodes.map(\.row).max() ?? 0) + 1
        var lines: [[Character]] = Array(
            repeating: Array(repeating: " ", count: Columns.textWidth), count: rows * 2 - 1)
        for node in nodes where node.visibility != .hidden {
            let x = node.column * 7
            let token = Array(token(for: node))
            for (offset, character) in token.enumerated() where x + offset < Columns.textWidth {
                lines[node.row * 2][x + offset] = character
            }
            if node.contested { lines[node.row * 2][x + 4] = "!" }
        }
        for link in state.network.links where link.count == 2 {
            let a = nodes[link[0]]
            let b = nodes[link[1]]
            guard a.visibility != .hidden, b.visibility != .hidden else { continue }
            if a.row == b.row {
                let x = min(a.column, b.column) * 7 + 4
                for offset in 0..<3 where lines[a.row * 2][x + offset] == " " {
                    lines[a.row * 2][x + offset] = "-"
                }
            } else {
                lines[min(a.row, b.row) * 2 + 1][a.column * 7 + 1] = "|"
            }
        }
        return lines.map { String(String($0).reversed().drop { $0 == " " }.reversed()) }
    }

    private func token(for node: NetworkNode) -> String {
        let isTarget = node.index == state.targetNode && !state.hasFile
        guard node.visibility == .scanned else { return isTarget ? "[\(node.index)$]" : "[\(node.index)?]" }
        let inner = "\(node.index)\(isTarget ? "$" : node.type.mapLetter)"
        if node.accessed { return "(\(inner))" }
        switch node.owner {
        case .player: return "<\(inner)>"
        case .sysop: return "{\(inner)}"
        case .neutral: return "[\(inner)]"
        }
    }

    func key() -> String {
        state.targetNode == nil || state.hasFile
            ? "<YOU> (ACCESS) {SYSOP} [FREE] ?" : "<YOU> (ACCESS) {SYSOP} [FREE] $FILE"
    }

    func sysopLine() -> String {
        guard let intent = state.sysopIntent else {
            return state.alertState == .dormant ? "SYSOP: DORMANT" : "SYSOP NEXT: -"
        }
        var line = "SYSOP NEXT: \(intent.label(content: content))"
        switch intent {
        case .harden(let node), .spawnICE(let node, _):
            if state.network.nodes[node].visibility == .hidden { line = "SYSOP NEXT: ACTIVITY ON AN UNKNOWN NODE" }
        default: break
        }
        if case .contest = intent { return style.blink(line) }
        return line
    }

    /// The line under the log: what can be attacked or must be reinforced.
    func targets() -> String {
        let attack = state.network.attackable.map(String.init).joined(separator: " ")
        let contested = state.network.nodes.filter { $0.isFoothold && $0.contested }.map { "\($0.index)" }
        var line = "ATTACK: \(attack.isEmpty ? "-" : attack)"
        if !contested.isEmpty { line += "  REINFORCE: " + contested.joined(separator: " ") }
        return line
    }
}
