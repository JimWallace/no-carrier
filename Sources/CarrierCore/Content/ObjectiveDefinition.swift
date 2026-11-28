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
    /// A node that holds what the contract is after (EXFILTRATION's file).
    public var target: TargetSpec?
    /// Cards added to the loot pool for this objective only (addendum 01,
    /// §5), so other objectives' loot draws do not move.
    public var extraRewards: [String]

    public init(
        id: String, name: String, win: ObjectiveWin, startAlert: Int, fog: FogMode, ghost: Bool,
        target: TargetSpec? = nil, extraRewards: [String] = []
    ) {
        self.id = id
        self.name = name
        self.win = win
        self.startAlert = startAlert
        self.fog = fog
        self.ghost = ghost
        self.target = target
        self.extraRewards = extraRewards
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, win, startAlert, fog, ghost, target, extraRewards
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        win = try container.decode(ObjectiveWin.self, forKey: .win)
        startAlert = try container.decode(Int.self, forKey: .startAlert)
        fog = try container.decode(FogMode.self, forKey: .fog)
        ghost = try container.decode(Bool.self, forKey: .ghost)
        target = try container.decodeIfPresent(TargetSpec.self, forKey: .target)
        extraRewards = try container.decodeIfPresent([String].self, forKey: .extraRewards) ?? []
    }
}

/// The TARGET node an objective needs (addendum 01, §3.2).
public struct TargetSpec: Codable, Sendable, Equatable {
    /// The type the TARGET node takes.
    public var nodeType: NodeType
    /// The file's size in MB.
    public var fileMB: HPRange
    /// The fewest hops from ENTRY the TARGET may be.
    public var minDistance: Int

    public init(nodeType: NodeType, fileMB: HPRange, minDistance: Int) {
        self.nodeType = nodeType
        self.fileMB = fileMB
        self.minDistance = minDistance
    }
}

/// How an objective is won. M5 has one; M6 onward add more.
public enum ObjectiveWin: String, Codable, Sendable, Equatable {
    /// Capture ROOT. The contract ends at once.
    case captureRoot
    /// Copy the TARGET's file, then JACK OUT (addendum 01, §3.2).
    case exfiltrate
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
