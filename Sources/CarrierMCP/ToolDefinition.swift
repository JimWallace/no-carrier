/// One tool as `tools/list` shows it.
package struct ToolDefinition: Sendable {
    package let name: String
    package let description: String
    package let properties: [String: JSONValue]
    package let required: [String]

    var json: JSONValue {
        [
            "name": .string(name),
            "description": .string(description),
            "inputSchema": [
                "type": "object",
                "properties": .object(properties),
                "required": .strings(required),
                "additionalProperties": false,
            ],
        ]
    }
}

/// What a tool call returns: text for the model, and whether it failed.
package struct ToolResult: Sendable, Equatable {
    package let value: JSONValue
    package let isError: Bool

    static func ok(_ value: JSONValue) -> Self { Self(value: value, isError: false) }
    static func error(_ message: String) -> Self { Self(value: ["error": .string(message)], isError: true) }

    /// MCP's `CallToolResult`: one text block that holds the JSON. There is
    /// no `structuredContent` copy, so a client does not show the model the
    /// same view twice.
    var json: JSONValue {
        [
            "content": [["type": "text", "text": .string(MCPServer.encode(value))]],
            "isError": .bool(isError),
        ]
    }
}
