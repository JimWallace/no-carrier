public import CarrierCore

/// Why a content directory could not become a `ContentPack`.
public enum ContentLoadError: Error, Sendable, Equatable, CustomStringConvertible {
    case missingBundle
    case missingFile(name: String, directory: String)
    case unreadable(name: String, reason: String)
    case invalidJSON(name: String, reason: String)
    case invalidContent([ContentError])

    public var description: String {
        switch self {
        case .missingBundle:
            "the content bundle is missing from this build"
        case .missingFile(let name, let directory):
            "\(name) is missing from \(directory)"
        case .unreadable(let name, let reason):
            "\(name) cannot be read: \(reason)"
        case .invalidJSON(let name, let reason):
            "\(name) is not valid content JSON: \(reason)"
        case .invalidContent(let errors):
            "the content does not validate:\n" + errors.map { "  - \($0.description)" }.joined(separator: "\n")
        }
    }
}
