import CarrierCore

/// The network as the player knows it (addendum 01, §2.3). The fog holds:
///
/// - a HIDDEN node is not listed, and no link to it is;
/// - a DETECTED node shows only its place on the grid, and the target mark;
/// - only a SCANNED node shows its type, owner and machine, as `INFO` does.
///
/// The weak and resist tags are never listed here: only PROBE, in a fight,
/// shows them.
enum PlayerMap {
    static func json(_ state: ContractState, content: ContentPack) -> JSONValue {
        let nodes = state.network.nodes
        let shown = nodes.filter { $0.visibility != .hidden }
        let links: [JSONValue] = state.network.links.compactMap { link in
            guard link.count == 2, nodes.indices.contains(link[0]), nodes.indices.contains(link[1]),
                nodes[link[0]].visibility != .hidden, nodes[link[1]].visibility != .hidden
            else { return nil }
            return [.int(link[0]), .int(link[1])]
        }
        return [
            "nodes": .array(shown.map { node($0, state: state, content: content) }),
            "links": .array(links),
            "attackable": .array(state.network.attackable.map(JSONValue.int)),
        ]
    }

    private static func node(_ node: NetworkNode, state: ContractState, content: ContentPack) -> JSONValue {
        var fields: [String: JSONValue] = [
            "node": .int(node.index),
            "row": .int(node.row),
            "column": .int(node.column),
            "visibility": .string(node.visibility.rawValue),
        ]
        if node.index == state.targetNode { fields["target"] = true }
        guard node.visibility == .scanned else { return .object(fields) }
        fields["type"] = .string(node.type.label)
        fields["owner"] = .string(node.owner.rawValue)
        if node.accessed { fields["accessed"] = true }
        if node.contested { fields["contested"] = true }
        let machine = node.machine
        fields["machine"] = [
            "os": .string("\(machine.osName) \(machine.osVersion)"),
            "hostname": .string(machine.hostname),
            "cpu": .string(machine.cpu.name),
            "ram_mb": .int(machine.ramMB),
            "modem": .string(machine.modem.name),
            "ice": .strings(machine.ice.map { content.iceDefinition($0)?.name ?? $0 }),
            "layers": .array(machine.layers.map { ["layer": .string($0.kind.label), "hp": .int($0.hp)] }),
        ]
        return .object(fields)
    }
}
