/// A gameplay mechanic that can be switched on or off (addendum 02, §1).
/// Every mechanic added after the MVP has one. `flags.json` gives each its
/// description, default, category and requirements; the rules read the
/// composed value from `RuleSet.flags`.
///
/// A flag that a recorded RuleSet does not name is off: the mechanic did
/// not exist when the replay was recorded.
public enum MechanicFlag: String, Codable, Sendable, CaseIterable, Comparable {
    /// Noise and Alert (M5). Off: no Alert, and the sysop is ACTIVE for the
    /// whole contract, as in the MVP.
    case alert
    /// The sysop's REVOKE intent on a node the player has access to (M5).
    case revoke
    /// CLAIM or GHOST when AUTH falls (M5).
    case ghost
    /// Fog of war (M5). The objective's `fog` gives the mode.
    case fog
    /// SCAN as a network action (M5).
    case scan
    /// The JACK OUT action (M5).
    case jackOut
    /// The objective's TARGET and its TRANSFER (M6).
    case transfer
    /// The objective's `extraRewards` in the loot pool (M6).
    case objectiveLoot

    /// The name as a terminal line shows it.
    public var label: String {
        switch self {
        case .jackOut: "JACK OUT"
        case .objectiveLoot: "OBJECTIVE LOOT"
        default: rawValue.uppercased()
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        let order = allCases
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}
