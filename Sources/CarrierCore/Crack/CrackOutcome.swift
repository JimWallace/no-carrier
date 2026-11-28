/// How a crack ended.
public enum CrackOutcome: String, Codable, Sendable, Equatable {
    /// Every slot was a hit.
    case cracked
    /// The alarm filled.
    case traced
    case loggedOut
}
