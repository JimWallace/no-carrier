/// One slot's mark under the `slots` feedback style.
public enum CrackMark: String, Codable, Sendable, Equatable {
    /// Right symbol, right slot.
    case hit
    /// The symbol is in the code, in another slot not already matched.
    case near
    case miss

    /// One character for the screen.
    public var glyph: String {
        switch self {
        case .hit: "H"
        case .near: "N"
        case .miss: "-"
        }
    }
}
