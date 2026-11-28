/// How aware the sysop is of the player (addendum 01, §2.1).
public enum AlertState: String, Codable, Sendable, CaseIterable, Comparable {
    /// No map intents; no Trace drift.
    case dormant
    /// Defensive intents only (HARDEN, SPAWN ICE).
    case suspicious
    /// Every intent. Once reached, it stays for the contract.
    case active

    public var label: String { rawValue.uppercased() }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (allCases.firstIndex(of: lhs) ?? 0) < (allCases.firstIndex(of: rhs) ?? 0)
    }

    /// The state for an Alert value under `tuning`, before the ACTIVE latch.
    public static func of(_ alert: Int, tuning: AlertTuning) -> Self {
        if alert >= tuning.active { return .active }
        if alert >= tuning.suspicious { return .suspicious }
        return .dormant
    }
}
