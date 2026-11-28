import CarrierCore
import CarrierMCP
import Foundation
import TestSupport
import Testing

/// The fog holds (addendum 01, §2.3): no tool shows what a human player could
/// not see. The checks run on every view of whole contracts played through
/// the server, and compare it with the rule state that the tools hide.
@Suite struct FogTests {
    let content: ContentPack

    init() throws {
        content = try BundledContent.load()
    }

    /// Every key in a JSON value, at any depth.
    func keys(_ value: JSONValue) -> Set<String> {
        switch value {
        case .object(let fields): fields.keys.reduce(into: Set(fields.keys)) { $0.formUnion(keys(fields[$1] ?? .null)) }
        case .array(let items): items.reduce(into: []) { $0.formUnion(keys($1)) }
        default: []
        }
    }

    /// Checks one full view against the hidden state.
    func checkFog(_ view: JSONValue, state: ContractState, fought: Set<Int>) throws {
        let text = MCPServer.encode(view)
        let listed = Set(view["map"]?["nodes"]?.arrayValue?.compactMap { $0["node"]?.intValue } ?? [])
        for node in state.network.nodes {
            let entry = view["map"]?["nodes"]?.arrayValue?.first { $0["node"]?.intValue == node.index }
            switch node.visibility {
            case .hidden:
                #expect(!listed.contains(node.index), "hidden node \(node.index) is listed")
            case .detected:
                #expect(entry?["type"] == nil && entry?["owner"] == nil && entry?["machine"] == nil)
            case .scanned:
                #expect(entry?["type"] != nil)
            }
            // Two nodes can share a hostname, so only a name that no known
            // machine has can show a leak.
            let known = state.network.nodes.filter { $0.visibility == .scanned || fought.contains($0.index) }
            if node.visibility != .scanned && !fought.contains(node.index)
                && !known.contains(where: { $0.machine.hostname == node.machine.hostname })
            {
                #expect(!text.contains(node.machine.hostname), "the machine of unscanned node \(node.index) shows")
            }
        }
        for link in view["map"]?["links"]?.arrayValue ?? [] {
            for end in link.arrayValue ?? [] {
                #expect(listed.contains(end.intValue ?? -1), "a link goes to a node that is not shown")
            }
        }
        switch state.sysopIntent {
        case .harden(let node), .spawnICE(let node, _):
            if state.network.nodes[node].visibility == .hidden {
                #expect(!text.contains("NODE \(node)"), "the sysop's move on hidden node \(node) shows")
            }
        default: break
        }
        let found = keys(view)
        #expect(found.isDisjoint(with: ["rng", "drawPile", "draw_order", "upgradeTaken"]))
        if let fight = state.fight {
            let panel = try #require(view["fight"])
            #expect(panel["draw_pile"] == .int(fight.drawPile.count))
            if !fight.revealed {
                #expect(panel["weak"] == "???")
                #expect(panel["resist"] == "???")
            }
        }
    }

    @Test(arguments: ["exfiltration", "infiltrate"], [UInt64(3), 8, 21, 1994])
    func theFogHoldsThroughAWholeContract(objective: String, seed: UInt64) throws {
        var client = try MCPClient()
        _ = try client.call("new_contract", ["objective": .string(objective), "seed": .string(String(seed))])
        let bot = GreedyContractBot(engine: ContractEngine(content: content), patience: 6)
        var fought: Set<Int> = []
        var sawHidden = false
        for _ in 0..<400 {
            let state = try #require(client.server.tools.contractState("g1"))
            let view = try #require(client.call("view", ["game_id": "g1"]).value["view"])
            try checkFog(view, state: state, fought: fought)
            let logText = MCPServer.encode(try client.call("log", ["game_id": "g1", "last": 1000]).value)
            let known = state.network.nodes.filter { $0.visibility == .scanned || fought.contains($0.index) }
            for node in state.network.nodes where node.visibility == .hidden {
                sawHidden = true
                if !known.contains(where: { $0.machine.hostname == node.machine.hostname }) {
                    #expect(!logText.contains(node.machine.hostname))
                }
            }
            guard state.outcome == nil else { break }
            let action = bot.choose(state)
            if case .attack(let node) = action { fought.insert(node) }
            _ = try client.call("act", ["game_id": "g1", "action": .string(MCPClient.id(for: action)), "view": "none"])
        }
        #expect(sawHidden, "the contract never had a hidden node, so the test checked nothing")
    }

    @Test func weakAndResistShowOnlyAfterProbe() throws {
        var client = try MCPClient()
        _ = try client.call("new_fight", ["seed": "12", "view": "none"])
        var sawRevealed = false
        for _ in 0..<40 {
            let fight = try #require(client.server.tools.fightState("g1")?.fight)
            let panel = try #require(client.call("view", ["game_id": "g1"]).value["view"]?["fight"])
            if fight.revealed {
                sawRevealed = true
                #expect(panel["weak"] != "???")
            } else {
                #expect(panel["weak"] == "???")
                #expect(panel["resist"] == "???")
            }
            guard !fight.isOver else { break }
            let probe = fight.hand.firstIndex { $0.cardID == "probe" }
            let action = probe.map { "play-\($0 + 1)" } ?? "end"
            _ = try client.call("act", ["game_id": "g1", "action": .string(action), "view": "none"])
        }
        #expect(sawRevealed, "PROBE never ran, so the test checked only one side")
    }

    @Test func theHandShowsButTheDrawPileIsOnlyACount() throws {
        var client = try MCPClient()
        _ = try client.call("new_fight", ["seed": "12", "view": "none"])
        let fight = try #require(client.server.tools.fightState("g1")?.fight)
        let panel = try #require(client.call("view", ["game_id": "g1"]).value["view"]?["fight"])
        #expect(panel["hand"]?.arrayValue?.count == fight.hand.count)
        #expect(panel["draw_pile"] == .int(fight.drawPile.count))
    }
}
