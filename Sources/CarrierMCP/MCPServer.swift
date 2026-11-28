package import CarrierCore
import Foundation

/// A Model Context Protocol server over stdio: JSON-RPC 2.0, one message per
/// line. It implements only what a Claude Code client needs: `initialize`,
/// `notifications/initialized`, `ping`, `tools/list` and `tools/call`.
///
/// The server holds no rule. Its tools send actions to `ContractEngine` and
/// `Engine` through the terminal's sessions, and render what comes back.
package struct MCPServer {
    /// The protocol versions this server can speak, newest first.
    package static let protocolVersions = ["2025-06-18", "2025-03-26", "2024-11-05"]

    package private(set) var tools: GameTools
    package private(set) var initialized = false

    /// `newSeed` gives the seed of a game started without one. The CLI draws
    /// it at random; a test passes a fixed list.
    package init(content: ContentPack, newSeed: @escaping () -> UInt64) {
        tools = GameTools(content: content, newSeed: newSeed)
    }

    /// Handles one line of input. Returns the response line, or nil for a
    /// notification (which gets no response).
    package mutating func handle(line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let message: JSONValue
        do {
            message = try JSONDecoder().decode(JSONValue.self, from: Data(trimmed.utf8))
        } catch {
            return Self.encode(Self.errorResponse(id: .null, .parseError("not valid JSON")))
        }
        if case .array = message {
            // MCP 2025-06-18 removed batches; the older versions allow them,
            // but no client this server is for sends one.
            return Self.encode(Self.errorResponse(id: .null, .invalidRequest("batches are not supported")))
        }
        return handle(message: message).map(Self.encode)
    }

    /// Handles one decoded message.
    package mutating func handle(message: JSONValue) -> JSONValue? {
        guard case .object(let fields) = message else {
            return Self.errorResponse(id: .null, .invalidRequest("a message is a JSON object"))
        }
        let id = fields["id"]
        if let id, !Self.isValidID(id) {
            return Self.errorResponse(id: .null, .invalidRequest("id must be a string or an integer"))
        }
        guard fields["jsonrpc"] == "2.0" else {
            return Self.errorResponse(id: id ?? .null, .invalidRequest("jsonrpc must be \"2.0\""))
        }
        guard let method = fields["method"]?.stringValue else {
            // A response from the client (to a request this server never
            // sends) or nonsense. A message without id gets no answer.
            if fields["result"] != nil || fields["error"] != nil { return nil }
            return Self.errorResponse(id: id ?? .null, .invalidRequest("method is missing"))
        }
        let params = fields["params"] ?? .object([:])
        guard let id else {
            notify(method)
            return nil
        }
        switch request(method, params: params) {
        case .success(let result):
            return ["jsonrpc": "2.0", "id": id, "result": result]
        case .failure(let error):
            return Self.errorResponse(id: id, error)
        }
    }

    private mutating func notify(_ method: String) {
        if method == "notifications/initialized" { initialized = true }
        // Every other notification (cancelled, progress, roots) is ignored:
        // each request here finishes before the next line is read.
    }

    private mutating func request(_ method: String, params: JSONValue) -> Result<JSONValue, RPCError> {
        switch method {
        case "initialize":
            return .success(initialize(params))
        case "ping":
            return .success(.object([:]))
        case "tools/list":
            return .success(["tools": .array(GameTools.definitions.map(\.json))])
        case "tools/call":
            guard let name = params["name"]?.stringValue else {
                return .failure(.invalidParams("tools/call needs a tool name"))
            }
            let arguments = params["arguments"] ?? .object([:])
            guard case .object(let fields) = arguments else {
                return .failure(.invalidParams("arguments must be an object"))
            }
            guard GameTools.definitions.contains(where: { $0.name == name }) else {
                return .failure(.invalidParams("unknown tool: \(name)"))
            }
            return .success(tools.call(name, arguments: fields).json)
        default:
            return .failure(.methodNotFound(method))
        }
    }

    private func initialize(_ params: JSONValue) -> JSONValue {
        let asked = params["protocolVersion"]?.stringValue
        let version = asked.flatMap { Self.protocolVersions.contains($0) ? $0 : nil } ?? Self.protocolVersions[0]
        return [
            "protocolVersion": .string(version),
            "capabilities": ["tools": ["listChanged": false]],
            "serverInfo": ["name": "no-carrier", "version": .string(CarrierVersion.current)],
            "instructions": .string(Self.instructions),
        ]
    }

    static let instructions = """
        NO CARRIER: a hacking deckbuilder on a 40-column terminal. Start a game with new_contract or \
        new_fight. Each result holds a view: the screen a human sees, the hand, the map and the legal \
        actions. Send act with an action id from legal_actions, or with the text a human would type \
        (ATTACK 4, BRUTE.EXE, END, GHOST, JACK OUT). The fog holds: you see what a human player sees.
        """

    private static func isValidID(_ id: JSONValue) -> Bool {
        switch id {
        case .string, .int: true
        default: false
        }
    }

    static func errorResponse(id: JSONValue, _ error: RPCError) -> JSONValue {
        ["jsonrpc": "2.0", "id": id, "error": error.json]
    }

    /// One line of compact JSON with sorted keys.
    package static func encode(_ value: JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let failure = #"{"error":{"code":-32603,"message":"Internal error: cannot encode"},"id":null,"jsonrpc":"2.0"}"#
        guard let data = try? encoder.encode(value) else { return failure }
        return String(bytes: data, encoding: .utf8) ?? failure
    }
}
