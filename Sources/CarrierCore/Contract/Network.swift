/// A contract's network: the nodes and the links between them.
public struct Network: Codable, Sendable, Equatable {
    public var templateID: String
    public var orgName: String
    public var orgKind: String
    public var nodes: [NetworkNode]
    /// Pairs of node indices.
    public var links: [[Int]]

    public init(templateID: String, orgName: String, orgKind: String, nodes: [NetworkNode], links: [[Int]]) {
        self.templateID = templateID
        self.orgName = orgName
        self.orgKind = orgKind
        self.nodes = nodes
        self.links = links
    }

    /// The nodes linked to `index`, in ascending order.
    public func neighbours(of index: Int) -> [Int] {
        links.compactMap { link -> Int? in
            guard link.count == 2 else { return nil }
            if link[0] == index { return link[1] }
            if link[1] == index { return link[0] }
            return nil
        }.sorted()
    }

    public func isLinked(_ a: Int, _ b: Int) -> Bool {
        neighbours(of: a).contains(b)
    }

    /// Nodes the player can ATTACK: shown, not theirs, and either linked to
    /// one they own or have access to, or accessed themselves (to claim).
    public var attackable: [Int] {
        nodes.indices.filter { index in
            nodes[index].owner != .player && nodes[index].visibility != .hidden
                && (nodes[index].accessed || neighbours(of: index).contains { nodes[$0].isFoothold })
        }
    }

    public func count(owner: NodeOwner, type: NodeType) -> Int {
        nodes.count { $0.owner == owner && $0.type == type }
    }

    /// Steps from `start` to every node, or nil where it cannot be reached.
    public func distances(from start: Int) -> [Int?] {
        var distance: [Int?] = Array(repeating: nil, count: nodes.count)
        guard nodes.indices.contains(start) else { return distance }
        distance[start] = 0
        var frontier = [start]
        while !frontier.isEmpty {
            var next: [Int] = []
            for node in frontier {
                for other in neighbours(of: node) where distance[other] == nil {
                    distance[other] = (distance[node] ?? 0) + 1
                    next.append(other)
                }
            }
            frontier = next
        }
        return distance
    }
}
