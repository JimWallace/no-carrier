/// What a contract asks for, and how it starts (addendum 01, §3 and §8).
/// `objectives.json` lists them.
public struct ObjectiveDefinition: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var win: ObjectiveWin
    /// Alert when the contract starts. TAKEOVER starts at ACTIVE (70), which
    /// is the MVP.
    public var startAlert: Int
    public var fog: FogMode
    /// Breaching AUTH offers CLAIM or GHOST. Off for TAKEOVER.
    public var ghost: Bool

    public init(id: String, name: String, win: ObjectiveWin, startAlert: Int, fog: FogMode, ghost: Bool) {
        self.id = id
        self.name = name
        self.win = win
        self.startAlert = startAlert
        self.fog = fog
        self.ghost = ghost
    }
}

/// How an objective is won. M5 has one; M6 onward add more.
public enum ObjectiveWin: String, Codable, Sendable, Equatable {
    /// Capture ROOT. The contract ends at once.
    case captureRoot
}

/// How much of the network the player sees (addendum 01, §2.3).
public enum FogMode: String, Codable, Sendable, Equatable {
    /// Every node SCANNED: the MVP.
    case off
    /// Only ENTRY SCANNED; nodes linked to the player's are DETECTED; the
    /// rest HIDDEN.
    case on
    /// Every node DETECTED from the start; ENTRY SCANNED.
    case partial
}
