public import CarrierCore

/// Builds a contract's network (kickoff §3, "Map generation"): one of the
/// hand-authored templates, its open node types filled from weights, one
/// organisation for every machine, and a machine for every node.
public struct NetworkGenerator: Sendable {
    public let content: ContentPack

    public init(content: ContentPack) {
        self.content = content
    }

    public func generate(seed: UInt64) throws(GenerationError) -> Network {
        var rng = Xoshiro256StarStar(seed: Seed.derive(seed, "network"))
        let template = try rng.choose(content.maps, "maps")
        let machines = MachineGenerator(content: content)
        let org = try machines.makeOrg(rng: &rng)

        var types: [NodeType] = []
        for slot in template.nodes {
            if let fixed = slot.type {
                types.append(fixed)
            } else {
                types.append(try weightedType(&rng))
            }
        }

        var nodes: [NetworkNode] = []
        for (index, slot) in template.nodes.enumerated() {
            let role: NodeRole =
                switch (slot.owner, types[index]) {
                case (.sysop, .root): .root
                case (.sysop, _): .sysop
                default: .neutral
                }
            let machine = try machines.generate(seed: Seed.derive(seed, "node/\(index)"), role: role, org: org)
            nodes.append(
                NetworkNode(
                    index: index, column: slot.column, row: slot.row, type: types[index], owner: slot.owner,
                    machine: machine))
        }
        var network = Network(
            templateID: template.id, orgName: org.name, orgKind: org.template.label, nodes: nodes,
            links: template.links)
        ensureVirusNearEntry(&network, template: template)
        return network
    }

    private func weightedType(_ rng: inout Xoshiro256StarStar) throws(GenerationError) -> NodeType {
        let table = content.tuning.network.nodeTypes.table.filter { $0.1 > 0 }
        let total = table.reduce(0) { $0 + $1.1 }
        guard total > 0 else { throw .emptyChoice(field: "network.nodeTypes") }
        var roll = rng.nextInt(below: total)
        for (type, weight) in table {
            if roll < weight { return type }
            roll -= weight
        }
        return table[table.count - 1].0
    }

    /// Kickoff §3: at least one neutral VIRUS within 2 hops of ENTRY. When
    /// the draw gave none, the lowest-numbered open neutral node within 2
    /// hops becomes one. Neutral machines do not depend on the node type, so
    /// the change moves no other draw.
    private func ensureVirusNearEntry(_ network: inout Network, template: MapTemplate) {
        guard let entry = network.nodes.firstIndex(where: { $0.type == .entry }) else { return }
        let distances = network.distances(from: entry)
        let near = network.nodes.indices.filter { index in
            network.nodes[index].owner == .neutral && (distances[index].map { (1...2).contains($0) } ?? false)
        }
        if near.contains(where: { network.nodes[$0].type == .virus }) { return }
        if let index = near.first(where: { template.nodes[$0].type == nil }) {
            network.nodes[index].type = .virus
        }
    }
}
