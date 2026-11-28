import CarrierMCP
import Testing

/// `tools/list`: the tools and their input schemas.
@Suite struct ToolListTests {
    @Test func listsEveryTool() throws {
        var client = try MCPClient()
        let tools = try #require(try client.request("tools/list")["result"]?["tools"]?.arrayValue)
        let names = tools.compactMap { $0["name"]?.stringValue }
        #expect(
            names == ["new_contract", "new_fight", "view", "act", "log", "save_replay", "list_games", "end_game"])
    }

    @Test func everyToolHasAnObjectSchemaAndADescription() throws {
        var client = try MCPClient()
        let tools = try #require(try client.request("tools/list")["result"]?["tools"]?.arrayValue)
        for tool in tools {
            #expect(tool["inputSchema"]?["type"] == "object")
            #expect(tool["inputSchema"]?["properties"]?.objectValue != nil)
            #expect((tool["description"]?.stringValue ?? "").count > 20)
            for required in tool["inputSchema"]?["required"]?.arrayValue ?? [] {
                let key = try #require(required.stringValue)
                #expect(tool["inputSchema"]?["properties"]?[key] != nil, "\(key) is required but not described")
            }
        }
    }
}
