import CarrierCore
import CarrierMCP
import Foundation
import TestSupport
import Testing

/// Drives an `MCPServer` the way a client does: one JSON-RPC line in, one
/// line out.
struct MCPClient {
    var server: MCPServer
    private var nextID = 1

    init(seeds: [UInt64] = [42]) throws {
        let content = try BundledContent.load()
        var queue = seeds
        server = MCPServer(content: content) { queue.isEmpty ? 0 : queue.removeFirst() }
    }

    /// Sends a raw line and decodes the response, or nil for no response.
    mutating func send(line: String) throws -> JSONValue? {
        guard let response = server.handle(line: line) else { return nil }
        #expect(!response.contains("\n"), "a response is one line")
        return try JSONDecoder().decode(JSONValue.self, from: Data(response.utf8))
    }

    /// Sends a request and returns the whole response.
    mutating func request(_ method: String, _ params: JSONValue = [:]) throws -> JSONValue {
        let id = nextID
        nextID += 1
        let message: JSONValue = ["jsonrpc": "2.0", "id": .int(id), "method": .string(method), "params": params]
        let response = try #require(try send(line: MCPServer.encode(message)))
        #expect(response["id"] == .int(id))
        return response
    }

    /// Calls a tool and returns its decoded JSON and its error flag.
    mutating func call(_ tool: String, _ arguments: JSONValue = [:]) throws -> (value: JSONValue, isError: Bool) {
        let response = try request("tools/call", ["name": .string(tool), "arguments": arguments])
        let result = try #require(response["result"], "tools/call failed: \(response)")
        let text = try #require(result["content"]?.arrayValue?.first?["text"]?.stringValue)
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
        return (value, result["isError"] == .bool(true))
    }

    /// The id that the server's action menu gives `action`. A reward that
    /// replaces a card names its deck place.
    static func id(for action: ContractAction) -> String {
        switch action {
        case .attack(let node): "attack-\(node)"
        case .reinforce(let node): "reinforce-\(node)"
        case .scan(let node): "scan-\(node)"
        case .wait: "wait"
        case .jackOut: "jack-out"
        case .claim: "claim"
        case .ghost: "ghost"
        case .skipReward: "skip"
        case .takeReward(let choice, nil): "take-\(choice + 1)"
        case .takeReward(let choice, let replacing?): "take-\(choice + 1)-delete-\(replacing + 1)"
        case .chooseUpgrade(let choice): "upgrade-\(choice + 1)"
        case .fight(let action): id(for: action)
        }
    }

    static func id(for action: Action) -> String {
        switch action {
        case .play(let index): "play-\(index + 1)"
        case .endTurn: "end"
        case .logout: "logout"
        }
    }
}
