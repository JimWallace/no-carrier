/// A content pack that does not hang together. `ContentPack.validate()`
/// returns every one it finds.
public enum ContentError: Error, Sendable, Equatable, CustomStringConvertible {
    case duplicateID(kind: String, id: String)
    case unknownCard(id: String, referencedBy: String)
    case unknownICE(id: String, referencedBy: String)
    case unknownOSFamily(id: String, referencedBy: String)
    case unknownCPU(name: String, referencedBy: String)
    case unknownModem(name: String, referencedBy: String)
    case emptyList(field: String)
    case invalidValue(field: String, reason: String)

    public var description: String {
        switch self {
        case .duplicateID(let kind, let id): "two \(kind) entries share the id \"\(id)\""
        case .unknownCard(let id, let by): "\(by) names the card \"\(id)\", which does not exist"
        case .unknownICE(let id, let by): "\(by) names the ICE \"\(id)\", which does not exist"
        case .unknownOSFamily(let id, let by): "\(by) names the OS family \"\(id)\", which does not exist"
        case .unknownCPU(let name, let by): "\(by) names the CPU \"\(name)\", which does not exist"
        case .unknownModem(let name, let by): "\(by) names the modem \"\(name)\", which does not exist"
        case .emptyList(let field): "\(field) is empty"
        case .invalidValue(let field, let reason): "\(field): \(reason)"
        }
    }
}
