import ArgumentParser
import CarrierMCP

/// `carrier mcp`: an MCP server on standard input and output, so a Claude
/// Code session can play contracts and fights and report how they play.
struct MCPCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Run an MCP server on stdio, for a Claude Code playtest session.",
        discussion: """
            Reads JSON-RPC 2.0 messages, one per line, from standard input, and writes one response per \
            line to standard output. See docs/playtest/mcp-playtesting.md.
            """
    )

    @OptionGroup var contentOptions: ContentOptions

    func run() throws {
        let content = try contentOptions.load()
        // A game started without a seed gets a random one. The server prints
        // it in every view, so the game can be played again.
        var server = MCPServer(content: content) { UInt64.random(in: 0...UInt64.max) }
        while let line = readLine(strippingNewline: true) {
            if let response = server.handle(line: line) {
                Output.write(response + "\n")
            }
        }
    }
}
