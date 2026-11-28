/// What the player knows about a node (addendum 01, §2.3).
public enum Visibility: String, Codable, Sendable, Comparable {
    /// Not shown.
    case hidden
    /// Shown, but its type, owner and machine are unknown.
    case detected
    /// Everything known.
    case scanned

    public static func < (lhs: Self, rhs: Self) -> Bool {
        let order: [Self] = [.hidden, .detected, .scanned]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}
