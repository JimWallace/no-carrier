import CarrierCore
import CarrierGen
import TestSupport
import Testing

@Suite struct NetworkGeneratorTests {
    @Test func sameSeedSameNetwork() throws {
        let generator = NetworkGenerator(content: try BundledContent.load())
        #expect(try generator.generate(seed: 7) == generator.generate(seed: 7))
    }

    @Test func everyNetworkFollowsTheBrief() throws {
        let content = try BundledContent.load()
        let generator = NetworkGenerator(content: content)
        var templates: Set<String> = []
        for seed in 0..<60 {
            let network = try generator.generate(seed: UInt64(seed))
            templates.insert(network.templateID)
            #expect((8...10).contains(network.nodes.count))
            let entry = try #require(network.nodes.firstIndex { $0.type == .entry })
            let root = try #require(network.nodes.firstIndex { $0.type == .root })
            let distances = network.distances(from: entry)
            #expect((3...4).contains(distances[root] ?? 0))
            #expect(
                network.nodes.indices.contains { index in
                    network.nodes[index].type == .virus && network.nodes[index].owner == .neutral
                        && (distances[index] ?? 9) <= 2
                })
            #expect(Set(network.nodes.map(\.machine.orgName)) == [network.orgName])
            #expect(network.nodes[root].machine.ice.first == "operator")
            #expect(network.nodes.filter { $0.owner == .sysop }.allSatisfy { $0.machine.layers.count == 3 })
            #expect((3...4).contains(network.nodes.count { $0.owner == .sysop }))
        }
        #expect(templates.count == content.maps.count)
    }
}
