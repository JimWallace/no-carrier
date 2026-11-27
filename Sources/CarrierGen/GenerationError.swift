import CarrierCore

/// A generator that met content it cannot use. `ContentPack.validate()`
/// rules every one of these out, so a validated pack never throws.
public enum GenerationError: Error, Sendable, Equatable, CustomStringConvertible {
    case emptyChoice(field: String)
    case unknownReference(field: String, name: String)

    public var description: String {
        switch self {
        case .emptyChoice(let field): "nothing to choose from in \(field)"
        case .unknownReference(let field, let name): "\(field) names \"\(name)\", which does not exist"
        }
    }
}

extension Xoshiro256StarStar {
    /// `pick`, with an error that names the empty list.
    mutating func choose<T>(_ items: [T], _ field: String) throws(GenerationError) -> T {
        guard let item = pick(items) else { throw .emptyChoice(field: field) }
        return item
    }
}
