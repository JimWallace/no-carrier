import CarrierCore
import CarrierMCP
import TestSupport
import Testing

/// A refused action returns its reason and changes nothing: not the state,
/// not the log, not the replay.
@Suite struct RejectionTests {
    func started() throws -> MCPClient {
        var client = try MCPClient()
        _ = try client.call("new_contract", ["seed": "1994", "view": "none"])
        return client
    }

    func logCount(_ client: inout MCPClient) throws -> JSONValue? {
        try client.call("log", ["game_id": "g1", "last": 0]).value["total"]
    }

    @Test(arguments: [
        ("attack-9", "?NO NODE 9"),
        ("ATTACK 9", "?NO NODE 9"),
        ("reinforce-0", "?NODE 0 IS NOT CONTESTED"),
        ("claim", "?NOT NOW"),
        ("play-1", "?NOT NOW"),
        ("take-1", "?NOT NOW"),
        ("FROBNICATE", "?SYNTAX ERROR"),
        ("QUIT", "?USE end_game TO LEAVE A GAME"),
        ("", "?EMPTY ACTION"),
    ])
    func aRefusedActionChangesNothing(action: String, reason: String) throws {
        var client = try started()
        let state = client.server.tools.contractState("g1")
        let log = try logCount(&client)
        let (value, isError) = try client.call("act", ["game_id": "g1", "action": .string(action)])
        #expect(isError)
        #expect(value["status"] == "rejected")
        #expect(value["lines"]?.arrayValue?.contains(.string(reason)) == true, "\(value)")
        #expect(client.server.tools.contractState("g1") == state)
        #expect(try logCount(&client) == log)
        #expect(try client.call("list_games").value["games"]?.arrayValue?.first?["actions"] == .int(0))
    }

    @Test func aCardThatCannotRunIsRefusedInAFight() throws {
        var client = try started()
        let state = try #require(client.server.tools.contractState("g1"))
        let node = try #require(state.network.attackable.first)
        _ = try client.call("act", ["game_id": "g1", "action": .string("attack-\(node)")])
        let before = client.server.tools.contractState("g1")
        let (value, isError) = try client.call("act", ["game_id": "g1", "action": "play-11"])
        #expect(isError)
        #expect(value["lines"] == .strings(["?NO CARD 11"]))
        #expect(client.server.tools.contractState("g1") == before)
    }

    @Test func aCardNotInHandIsRefusedInTheSandbox() throws {
        var client = try MCPClient()
        _ = try client.call("new_fight", ["seed": "3", "view": "none"])
        let before = client.server.tools.fightState("g1")
        let (value, isError) = try client.call("act", ["game_id": "g1", "action": "PAYLOAD"])
        #expect(isError)
        #expect(value["status"] == "rejected")
        #expect(client.server.tools.fightState("g1") == before)
    }

    @Test func aHugeNumberIsRefusedNotACrash() throws {
        var client = try started()
        let (_, isError) = try client.call("act", ["game_id": "g1", "action": "take-9223372036854775807-delete-1"])
        #expect(isError)
        let (_, playError) = try client.call("act", ["game_id": "g1", "action": "play--9223372036854775808"])
        #expect(playError)
    }

    @Test(arguments: ["wait", "WAIT", "ATTACK 1", "7"])
    func anActionAfterTheEndIsRefused(action: String) throws {
        var client = try started()
        _ = try client.call("act", ["game_id": "g1", "action": "jack-out"])
        let (value, isError) = try client.call("act", ["game_id": "g1", "action": .string(action)])
        #expect(isError)
        #expect(value["lines"] == .strings(["?CONTRACT CLOSED"]))
    }

    /// A typed loot number with Storage full waits for a deck number. An
    /// action id given after it must not leave that half-made choice behind.
    @Test func anActionIDClearsAHalfMadeLootChoice() throws {
        let content = try BundledContent.load()
        let bot = GreedyContractBot(engine: ContractEngine(content: content))
        var client = try MCPClient()
        _ = try client.call("new_contract", ["seed": "2", "view": "none"])
        var full = false
        for _ in 0..<2000 {
            let state = try #require(client.server.tools.contractState("g1"))
            guard state.outcome == nil else { break }
            if case .reward = state.phase, state.deck.count >= state.storage {
                full = true
                break
            }
            let id = MCPClient.id(for: bot.choose(state))
            _ = try client.call("act", ["game_id": "g1", "action": .string(id), "view": "none"])
        }
        try #require(full, "the contract never offered loot with Storage full")
        #expect(try client.call("act", ["game_id": "g1", "action": "1", "view": "none"]).value["status"] == "info")
        _ = try client.call("act", ["game_id": "g1", "action": "skip", "view": "none"])
        // The stale choice would show on the next loot screen.
        var sawLoot = false
        for _ in 0..<2000 {
            let state = try #require(client.server.tools.contractState("g1"))
            guard state.outcome == nil else { break }
            if case .reward = state.phase {
                sawLoot = true
                let screen = try #require(client.call("view", ["game_id": "g1"]).value["view"]?["screen"])
                #expect(!MCPServer.encode(screen).contains("DELETE: DECK NUMBER"))
                break
            }
            let id = MCPClient.id(for: bot.choose(state))
            _ = try client.call("act", ["game_id": "g1", "action": .string(id), "view": "none"])
        }
        try #require(sawLoot, "no second loot screen, so the test checked nothing")
    }
}
