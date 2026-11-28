import CarrierCore
import CarrierGen
import CarrierMCP
import Foundation
import TestSupport
import Testing

/// `new_contract` takes `flags` and `unsafe`, as `carrier play` takes
/// `--flag` and `--unsafe` (addendum 02, §1).
@Suite struct RuleFlagTests {
    @Test func noFlagsGivesTheObjectiveDefaults() throws {
        var client = try MCPClient()
        _ = try client.call("new_contract", ["objective": "exfiltration", "seed": "5", "view": "none"])
        let content = try BundledContent.load()
        let objective = try #require(content.objective("exfiltration"))
        #expect(
            client.server.tools.contractState("g1")?.rules == RuleSet.defaults(content: content, objective: objective))
        let view = try #require(client.call("view", ["game_id": "g1"]).value["view"])
        #expect(view["flags_changed"] == .array([]))
        #expect(view["flags"]?["fog"] == true)
    }

    @Test func aFlagChangesTheRules() throws {
        var client = try MCPClient()
        let (value, isError) = try client.call(
            "new_contract", ["objective": "exfiltration", "seed": "5", "flags": ["fog=off"], "view": "full"])
        #expect(!isError)
        let state = try #require(client.server.tools.contractState("g1"))
        #expect(!state.rules.isOn(.fog))
        // With the fog off, every node is known from the start.
        #expect(state.network.nodes.allSatisfy { $0.visibility == .scanned })
        #expect(value["view"]?["flags_changed"] == .strings(["fog=off"]))
        let games = try #require(client.call("list_games").value["games"]?.arrayValue)
        #expect(games.first?["flags_changed"] == .strings(["fog=off"]))
    }

    @Test func theSameFlagsMatchCarrierPlay() throws {
        let content = try BundledContent.load()
        let objective = try #require(content.objective("infiltrate"))
        let overrides = [try #require(FlagSetting.parse("alert=off")), try #require(FlagSetting.parse("SCAN=OFF"))]
        let rules = try RuleSet.compose(content: content, objective: objective, overrides: overrides)
        let network = try NetworkGenerator(content: content).generate(seed: 9)
        let (direct, _) = ContractEngine(content: content).start(
            seed: 9, network: network, objective: objective, rules: rules)
        var client = try MCPClient()
        _ = try client.call(
            "new_contract",
            ["objective": "infiltrate", "seed": "9", "flags": ["alert=off", "SCAN=OFF"], "view": "none"])
        #expect(client.server.tools.contractState("g1") == direct)
    }

    @Test(arguments: [
        JSONValue.strings(["fog=maybe"]),
        .strings(["warp=on"]),
        .array([.int(3)]),
        .int(1),
        .string("fog=off"),
    ])
    func aBadFlagIsAToolError(flags: JSONValue) throws {
        var client = try MCPClient()
        let (value, isError) = try client.call("new_contract", ["seed": "5", "flags": flags])
        #expect(isError)
        #expect(value["error"]?.stringValue?.contains("flag") == true)
        #expect(try client.call("list_games").value["games"] == .array([]))
    }

    @Test func aRefusedCallDrawsNoSeed() throws {
        var client = try MCPClient(seeds: [11, 12])
        #expect(try client.call("new_contract", ["flags": ["warp=on"]]).isError)
        #expect(try client.call("new_contract", ["flags": ["revoke=off"], "objective": "exfiltration"]).isError)
        #expect(try client.call("new_contract", ["unsafe": "yes"]).isError)
        let started = try client.call("new_contract", ["view": "none"])
        #expect(started.value["game_id"] == "g1")
        #expect(started.value["seed"] == .string(Seed.display(11)))
    }

    @Test func unsafeMustBeABoolean() throws {
        var client = try MCPClient()
        let (value, isError) = try client.call("new_contract", ["seed": "5", "unsafe": "yes"])
        #expect(isError)
        #expect(value["error"] == "unsafe must be true or false")
    }

    @Test func nullFlagsAreNoFlags() throws {
        var client = try MCPClient()
        #expect(
            try !client.call("new_contract", ["seed": "5", "flags": .null, "unsafe": .null, "view": "none"]).isError)
        #expect(try client.call("view", ["game_id": "g1"]).value["view"]?["flags_changed"] == .array([]))
    }

    @Test func aBrokenRequirementNeedsUnsafe() throws {
        var client = try MCPClient()
        // EXFILTRATION turns GHOST on, and GHOST requires REVOKE.
        let refused = try client.call(
            "new_contract", ["objective": "exfiltration", "seed": "5", "flags": ["revoke=off"], "view": "none"])
        #expect(refused.isError)
        #expect(refused.value["error"]?.stringValue?.contains("unsafe: true allows it") == true)
        let allowed = try client.call(
            "new_contract",
            ["objective": "exfiltration", "seed": "5", "flags": ["revoke=off"], "unsafe": true, "view": "none"])
        #expect(!allowed.isError)
        #expect(client.server.tools.contractState("g1")?.rules.isOn(.revoke) == false)
    }

    @Test func theReplayRecordsTheFlags() throws {
        var client = try MCPClient()
        _ = try client.call(
            "new_contract", ["objective": "exfiltration", "seed": "5", "flags": ["fog=off"], "view": "none"])
        _ = try client.call("act", ["game_id": "g1", "action": "wait", "view": "none"])
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("carrier-mcp-flags-\(UInt64.random(in: 0...UInt64.max)).json").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(try !client.call("save_replay", ["game_id": "g1", "path": .string(path)]).isError)
        let replay = try JSONDecoder().decode(ContractReplay.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        #expect(replay.rules == client.server.tools.contractState("g1")?.rules)
        #expect(replay.rules?.isOn(.fog) == false)
    }
}
