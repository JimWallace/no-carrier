/// A JSON-RPC 2.0 error object. The codes are the ones the JSON-RPC
/// specification reserves.
package struct RPCError: Error, Equatable, Sendable {
    package let code: Int
    package let message: String

    package init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    package static func parseError(_ detail: String) -> Self { Self(code: -32_700, message: "Parse error: \(detail)") }
    package static func invalidRequest(_ detail: String) -> Self {
        Self(code: -32_600, message: "Invalid Request: \(detail)")
    }
    package static func methodNotFound(_ method: String) -> Self {
        Self(code: -32_601, message: "Method not found: \(method)")
    }
    package static func invalidParams(_ detail: String) -> Self {
        Self(code: -32_602, message: "Invalid params: \(detail)")
    }

    var json: JSONValue { ["code": .int(code), "message": .string(message)] }
}
