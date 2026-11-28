import CarrierCore
import CarrierGen
import CarrierMCP
import Foundation
import TestSupport
import Testing

/// A contract driven through `tools/call` plays exactly as the same seed and
/// actions played through `ContractEngine` directly.
@Suite struct ContractToolTests {
    let content: ContentPack
    let engine: ContractEngine

    init() throws {
        content = try BundledContent.load()
        engine = ContractEngine(content: content)
    }

    func direct(seed: UInt64, objective: String) throws -> (ContractState, [ContractAction]) {
        let network = try NetworkGenerator(content: content).generate(seed: seed)
        let definition = try #require(content.objective(objective))
        let (initial, _) = engine.start(seed: seed, network: network, objective: definition)
        let (final, actions, _) = GreedyContractBot(engine: engine).play(initial)
        return (final, actions)
    }

    @Test(arguments: [("takeover", UInt64(1994)), ("exfiltration", 7), ("infiltrate", 31)])
    func aScriptedContractMatchesTheEngine(objective: String, seed: UInt64) throws {
        let (final, actions) = try direct(seed: seed, objective: objective)
        var client = try MCPClient()
        let started = try client.call(
            "new_contract", ["objective": .string(objective), "seed": .string(String(seed)), "view": "none"])
        #expect(!started.isError)
        #expect(started.value["game_id"] == "g1")
        for action in actions {
            let (value, isError) = try client.call(
                "act", ["game_id": "g1", "action": .string(MCPClient.id(for: action)), "view": "none"])
            #expect(!isError, "\(action) was refused: \(value)")
            #expect(value["status"] == "ok")
        }
        #expect(client.server.tools.contractState("g1") == final)
        let view = try client.call("view", ["game_id": "g1"]).value
        #expect(view["view"]?["phase"] == "over")
        #expect(view["view"]?["legal_actions"] == .array([]))
    }

    @Test func everyLegalActionIsAcceptedAndEveryAcceptedActionIsListed() throws {
        // The menu offers only what the engine takes: walk a contract by
        // always taking the last legal action, which is JACK OUT on the map,
        // so take the first instead there.
        var client = try MCPClient()
        _ = try client.call("new_contract", ["objective": "exfiltration", "seed": "99", "view": "none"])
        for _ in 0..<300 {
            let view = try #require(try client.call("view", ["game_id": "g1", "detail": "compact"]).value["view"])
            let legal = view["legal_actions"]?.arrayValue ?? []
            guard let first = legal.first?["id"]?.stringValue else { break }
            let id = view["phase"] == "map" ? first : (legal.last?["id"]?.stringValue ?? first)
            let pick = id == "logout" && legal.count > 2 ? first : id
            let (value, isError) = try client.call("act", ["game_id": "g1", "action": .string(pick), "view": "none"])
            #expect(!isError, "\(pick) was listed but refused: \(value)")
        }
    }

    @Test func typedCommandsDriveTheSameActions() throws {
        var byID = try MCPClient()
        var byText = try MCPClient()
        _ = try byID.call("new_contract", ["seed": "1994", "view": "none"])
        _ = try byText.call("new_contract", ["seed": "1994", "view": "none"])
        let state = try #require(byID.server.tools.contractState("g1"))
        let node = try #require(state.network.attackable.first)
        _ = try byID.call("act", ["game_id": "g1", "action": .string("attack-\(node)")])
        let typed = try byText.call("act", ["game_id": "g1", "action": .string("attack \(node)")])
        #expect(typed.value["status"] == "ok")
        #expect(byID.server.tools.contractState("g1") == byText.server.tools.contractState("g1"))
        _ = try byID.call("act", ["game_id": "g1", "action": "end"])
        let end = try byText.call("act", ["game_id": "g1", "action": "END"])
        #expect(end.value["status"] == "ok")
        #expect(byID.server.tools.contractState("g1") == byText.server.tools.contractState("g1"))
    }

    @Test func aCardCanBeRunByName() throws {
        var client = try MCPClient()
        _ = try client.call("new_contract", ["seed": "1994", "view": "none"])
        let state = try #require(client.server.tools.contractState("g1"))
        let node = try #require(state.network.attackable.first)
        _ = try client.call("act", ["game_id": "g1", "action": .string("attack-\(node)")])
        let fight = try #require(client.server.tools.contractState("g1")?.fight)
        let index = try #require(
            fight.hand.indices.first { engine.fightEngine.rejection(forPlaying: $0, in: fight) == nil })
        let name = try #require(content.card(fight.hand[index].cardID)?.name)
        let (value, isError) = try client.call("act", ["game_id": "g1", "action": .string(name.lowercased())])
        #expect(!isError)
        #expect(value["lines"]?.arrayValue?.contains { $0.stringValue?.contains(name) == true } == true)
    }

    @Test func infoIsAnAnswerThatChangesNoState() throws {
        var client = try MCPClient()
        _ = try client.call("new_contract", ["seed": "1994", "view": "none"])
        let before = client.server.tools.contractState("g1")
        let (value, isError) = try client.call("act", ["game_id": "g1", "action": "INFO 0"])
        #expect(!isError)
        #expect(value["status"] == "info")
        #expect(client.server.tools.contractState("g1") == before)
    }

    @Test func theSameSeedAndActionsGiveTheSameBytes() throws {
        func play() throws -> [JSONValue] {
            var client = try MCPClient()
            var outputs = [try client.call("new_contract", ["seed": "5"]).value]
            for _ in 0..<20 {
                let view = try client.call("view", ["game_id": "g1"]).value
                let id = view["view"]?["legal_actions"]?.arrayValue?.first?["id"] ?? "wait"
                outputs.append(try client.call("act", ["game_id": "g1", "action": id]).value)
            }
            return outputs
        }
        #expect(try play() == play())
    }

    @Test func gamesAreListedAndEnded() throws {
        var client = try MCPClient(seeds: [11, 12])
        _ = try client.call("new_contract", ["view": "none"])
        _ = try client.call("new_fight", ["view": "none"])
        let games = try #require(client.call("list_games").value["games"]?.arrayValue)
        #expect(games.compactMap { $0["game_id"]?.stringValue } == ["g1", "g2"])
        #expect(games.first?["seed"] == .string(Seed.display(11)))
        #expect(games.last?["kind"] == "fight")
        #expect(try client.call("end_game", ["game_id": "g1"]).value["ended"] == true)
        #expect(try client.call("view", ["game_id": "g1"]).isError)
        #expect(try client.call("list_games").value["games"]?.arrayValue?.count == 1)
    }

    @Test func aBadObjectiveOrSeedIsAToolError() throws {
        var client = try MCPClient()
        #expect(try client.call("new_contract", ["objective": "heist"]).isError)
        #expect(try client.call("new_contract", ["seed": "banana"]).isError)
        #expect(try client.call("new_contract", ["seed": -1]).isError)
        #expect(try client.call("new_fight", ["role": "mainframe"]).isError)
        #expect(try client.call("list_games").value["games"] == .array([]))
    }
}
