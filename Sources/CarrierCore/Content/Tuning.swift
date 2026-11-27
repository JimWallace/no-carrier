/// Every tuning number (`tuning.json`). Nothing in Swift repeats one.
public struct Tuning: Codable, Sendable, Equatable {
    public var rig: RigTuning
    public var trace: TraceTuning
    /// The damage multiplier for a tag the OS is weak to, as a percent.
    public var weakPercent: Int
    /// The damage multiplier for a tag the OS resists, as a percent.
    public var resistPercent: Int
    public var starterDeck: [String]
    public var roles: RoleTable
    public var ice: ICETuning
    public var cpuTiers: [CPUTierTuning]
    public var filesystem: FilesystemTuning

    /// The tier entry for a CPU tier, or nil when the table has none.
    public func cpuTier(_ tier: Int) -> CPUTierTuning? {
        cpuTiers.first { $0.tier == tier }
    }
}

/// The player's starting cyberdeck (kickoff §5).
public struct RigTuning: Codable, Sendable, Equatable {
    public var cycles: Int
    public var ram: Int
    public var storage: Int
    public var bandwidth: Int
    public var integrity: Int
    public var handSize: Int
    public var maxHandSize: Int
}

public struct TraceTuning: Codable, Sendable, Equatable {
    /// Trace at or above this ends the contract: NO CARRIER.
    public var max: Int
    /// What LOGOUT costs.
    public var logout: Int
}

public struct RoleTable: Codable, Sendable, Equatable {
    public var neutral: RoleTuning
    public var sysop: RoleTuning
    public var root: RoleTuning

    public subscript(role: NodeRole) -> RoleTuning {
        switch role {
        case .neutral: neutral
        case .sysop: sysop
        case .root: root
        }
    }
}

/// How machines of one role are generated.
public struct RoleTuning: Codable, Sendable, Equatable {
    public var osFamilies: [String]
    public var ramMB: [Int]
    public var modems: [String]
    public var firewall: HPRange
    public var auth: HPRange
    public var kernel: HPRange?
    public var icePool: [String]
}

public struct HPRange: Codable, Sendable, Equatable {
    public var min: Int
    public var max: Int
}

public struct ICETuning: Codable, Sendable, Equatable {
    /// ICE programs = base + RAM / ramPerExtra, at most max (kickoff §6).
    public var base: Int
    public var ramPerExtra: Int
    public var max: Int
    /// Each layer gets one extra HP per this many MB of RAM.
    public var ramPerLayerHP: Int
}

/// What a CPU tier does to the machine's ICE.
public struct CPUTierTuning: Codable, Sendable, Equatable {
    public var tier: Int
    /// How many pattern steps each ICE program carries out per turn.
    public var intentsPerTurn: Int
    /// Added to every ATTACK intent ("stronger ICE").
    public var attackBonus: Int
}

public struct FilesystemTuning: Codable, Sendable, Equatable {
    public var homes: HPRange
    public var orgFiles: HPRange
}
