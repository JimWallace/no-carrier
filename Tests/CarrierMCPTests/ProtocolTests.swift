import CarrierMCP
import Testing

/// JSON-RPC 2.0 framing and the MCP handshake.
@Suite struct ProtocolTests {
    @Test func initializeAnswersWithTheToolsCapability() throws {
        var client = try MCPClient()
        let response = try client.request(
            "initialize",
            ["protocolVersion": "2025-06-18", "capabilities": [:], "clientInfo": ["name": "test", "version": "1"]])
        let result = try #require(response["result"])
        #expect(response["jsonrpc"] == "2.0")
        #expect(result["protocolVersion"] == "2025-06-18")
        #expect(result["capabilities"]?["tools"] != nil)
        #expect(result["serverInfo"]?["name"] == "no-carrier")
    }

    @Test func anUnknownProtocolVersionGetsTheNewest() throws {
        var client = try MCPClient()
        let response = try client.request("initialize", ["protocolVersion": "1999-01-01"])
        #expect(response["result"]?["protocolVersion"] == .string(MCPServer.protocolVersions[0]))
    }

    @Test func anOlderSupportedVersionIsKept() throws {
        var client = try MCPClient()
        let response = try client.request("initialize", ["protocolVersion": "2024-11-05"])
        #expect(response["result"]?["protocolVersion"] == "2024-11-05")
    }

    @Test func aNotificationGetsNoResponse() throws {
        var client = try MCPClient()
        #expect(try client.send(line: #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#) == nil)
        #expect(client.server.initialized)
        #expect(try client.send(line: #"{"jsonrpc":"2.0","method":"notifications/cancelled","params":{}}"#) == nil)
    }

    @Test func pingAnswersWithAnEmptyResult() throws {
        var client = try MCPClient()
        #expect(try client.request("ping")["result"] == .object([:]))
    }

    @Test func aStringIDIsEchoed() throws {
        var client = try MCPClient()
        let response = try #require(try client.send(line: #"{"jsonrpc":"2.0","id":"abc","method":"ping"}"#))
        #expect(response["id"] == "abc")
    }

    @Test func badJSONIsAParseError() throws {
        var client = try MCPClient()
        let response = try #require(try client.send(line: "{not json"))
        #expect(response["error"]?["code"] == .int(-32_700))
        #expect(response["id"] == .null)
    }

    @Test func blankLinesAreIgnored() throws {
        var client = try MCPClient()
        #expect(try client.send(line: "   ") == nil)
    }

    @Test(arguments: [
        #"{"id":1,"method":"ping"}"#,
        #"{"jsonrpc":"1.0","id":1,"method":"ping"}"#,
        #"{"jsonrpc":"2.0","id":1}"#,
        #"{"jsonrpc":"2.0","id":{"a":1},"method":"ping"}"#,
        #"[{"jsonrpc":"2.0","id":1,"method":"ping"}]"#,
        #""ping""#,
    ])
    func anInvalidRequestIsRefused(line: String) throws {
        var client = try MCPClient()
        let response = try #require(try client.send(line: line))
        #expect(response["error"]?["code"] == .int(-32_600))
    }

    @Test func aClientResponseGetsNoAnswer() throws {
        var client = try MCPClient()
        #expect(try client.send(line: #"{"jsonrpc":"2.0","id":7,"result":{}}"#) == nil)
    }

    @Test func anUnknownMethodIsMethodNotFound() throws {
        var client = try MCPClient()
        let response = try client.request("resources/list")
        #expect(response["error"]?["code"] == .int(-32_601))
    }

    @Test func anUnknownToolIsInvalidParams() throws {
        var client = try MCPClient()
        let response = try client.request("tools/call", ["name": "format_disk", "arguments": [:]])
        #expect(response["error"]?["code"] == .int(-32_602))
    }

    @Test func toolArgumentsMustBeAnObject() throws {
        var client = try MCPClient()
        let response = try client.request("tools/call", ["name": "list_games", "arguments": [1, 2]])
        #expect(response["error"]?["code"] == .int(-32_602))
    }

    @Test func aToolFailureIsAResultWithIsError() throws {
        var client = try MCPClient()
        let (value, isError) = try client.call("view", ["game_id": "g99"])
        #expect(isError)
        #expect(value["error"]?.stringValue?.contains("no game g99") == true)
    }
}
