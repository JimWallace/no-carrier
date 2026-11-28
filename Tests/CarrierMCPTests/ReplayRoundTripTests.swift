import CarrierCore
import CarrierGen
import CarrierMCP
import Foundation
import TestSupport
import Testing

/// `save_replay` writes the format `carrier replay` reads, and the replay
/// plays back to the same state.
@Suite struct ReplayRoundTripTests {
    let content: ContentPack

    init() throws {
        content = try BundledContent.load()
    }

    func temporaryPath(_ name: String) -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("carrier-mcp-\(name)-\(UInt64.random(in: 0...UInt64.max)).json").path
    }

    @Test func aContractReplayPlaysBackToTheSameState() throws {
        var client = try MCPClient()
        _ = try client.call("new_contract", ["objective": "exfiltration", "seed": "77", "view": "none"])
        let bot = GreedyContractBot(engine: ContractEngine(content: content))
        for _ in 0..<60 {
            let state = try #require(client.server.tools.contractState("g1"))
            guard state.outcome == nil else { break }
            _ = try client.call(
                "act", ["game_id": "g1", "action": .string(MCPClient.id(for: bot.choose(state))), "view": "none"])
        }
        // A refused action must not reach the replay.
        _ = try client.call("act", ["game_id": "g1", "action": "attack-9"])
        let path = temporaryPath("contract")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let saved = try client.call("save_replay", ["game_id": "g1", "path": .string(path)])
        #expect(!saved.isError)
        let replay = try JSONDecoder().decode(ContractReplay.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        #expect(replay.seed == 77)
        #expect(replay.objective == "exfiltration")
        let engine = ContractEngine(content: content)
        let network = try NetworkGenerator(content: content).generate(seed: replay.seed)
        var (state, _) = engine.start(
            seed: replay.seed, network: network, objective: try #require(content.objective("exfiltration")))
        for action in replay.actions {
            let (next, events) = engine.apply(action, to: state)
            #expect(
                events.count != 1 || events.first?.line(content: content).hasPrefix("?") == false,
                "\(action) was refused on replay")
            state = next
        }
        #expect(state == client.server.tools.contractState("g1"))
    }

    @Test func aFightReplayPlaysBackToTheSameState() throws {
        var client = try MCPClient()
        _ = try client.call("new_fight", ["role": "sysop", "seed": "0x2A", "view": "none"])
        for _ in 0..<30 {
            let view = try client.call("view", ["game_id": "g1", "detail": "compact"]).value
            guard let id = view["view"]?["legal_actions"]?.arrayValue?.first?["id"] else { break }
            _ = try client.call("act", ["game_id": "g1", "action": id, "view": "none"])
        }
        let path = temporaryPath("fight")
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(try !client.call("save_replay", ["game_id": "g1", "path": .string(path)]).isError)
        let replay = try JSONDecoder().decode(FightReplay.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        #expect(replay.seed == 0x2A)
        #expect(replay.role == .sysop)
        let engine = Engine(content: content)
        let setup = try SandboxFight.setup(
            seed: replay.seed, role: replay.role, payload: replay.payload, content: content)
        // The replay header carries the rules the fight ran under.
        let rules = try #require(replay.rules)
        #expect(rules == RuleSet.defaults(content: content, objective: nil))
        var (state, _) = engine.startFight(setup, rules: rules)
        for action in replay.actions {
            state = engine.apply(action, to: state).0
        }
        #expect(state == client.server.tools.fightState("g1"))
    }
}
