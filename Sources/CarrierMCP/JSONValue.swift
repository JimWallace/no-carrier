/// A JSON value: what JSON-RPC carries. Objects encode with sorted keys (see
/// `MCPServer.encode`), so the same game always prints the same bytes.
package enum JSONValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([Self])
    case object([String: Self])

    package subscript(key: String) -> Self? {
        if case .object(let fields) = self { return fields[key] }
        return nil
    }

    package var stringValue: String? {
        if case .string(let text) = self { return text }
        return nil
    }

    package var intValue: Int? {
        switch self {
        case .int(let value): value
        case .double(let value) where value.rounded() == value && abs(value) < 9e15: Int(value)
        default: nil
        }
    }

    package var arrayValue: [Self]? {
        if case .array(let items) = self { return items }
        return nil
    }

    package var objectValue: [String: Self]? {
        if case .object(let fields) = self { return fields }
        return nil
    }
}

extension JSONValue: Codable {
    package init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([Self].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: Self].self))
        }
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral,
    ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
{
    package init(stringLiteral value: String) { self = .string(value) }
    package init(integerLiteral value: Int) { self = .int(value) }
    package init(booleanLiteral value: Bool) { self = .bool(value) }
    package init(arrayLiteral elements: Self...) { self = .array(elements) }
    package init(dictionaryLiteral elements: (String, Self)...) {
        var fields: [String: Self] = [:]
        for (key, value) in elements { fields[key] = value }
        self = .object(fields)
    }
}

extension JSONValue {
    /// A list of strings.
    package static func strings(_ items: [String]) -> Self { .array(items.map(Self.string)) }

    /// A value, or JSON null when there is none.
    package static func optional(_ value: Self?) -> Self { value ?? .null }
}
