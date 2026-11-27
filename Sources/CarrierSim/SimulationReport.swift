public import CarrierCore

/// What `carrier sim` measured over many contracts (kickoff §8, "CLI
/// subcommands"). Counts only, kept in arrays aligned with content order so
/// that nothing depends on dictionary order.
public struct SimulationReport: Sendable, Equatable {
    /// How one contract ended, with `stalled` for one that hit the action
    /// limit.
    public enum Ending: String, Sendable, CaseIterable {
        case won
        case flatlined
        case traced
        case entryLost
        case stalled
    }

    public let bot: String
    public let seed: UInt64
    public var runs = 0
    /// Aligned with `Ending.allCases`.
    public var endings: [Int] = Array(repeating: 0, count: Ending.allCases.count)
    public var totalTraceAtEnd = 0
    public var totalTicks = 0
    public var totalActions = 0
    public var fights = 0
    public var logouts = 0
    /// Fights started on ROOT, and runs lost inside one.
    public var rootAttempts = 0
    public var endedAtRoot = 0
    /// Aligned with `NodeType.allCases`.
    public var capturesByType: [Int] = Array(repeating: 0, count: NodeType.allCases.count)
    /// Aligned with `rewardPool`.
    public let rewardPool: [String]
    public var offered: [Int]
    public var taken: [Int]
    /// Aligned with `upgrades`.
    public let upgrades: [RigUpgrade]
    public var upgradePicks: [Int]

    public init(bot: String, seed: UInt64, rewardPool: [String], upgrades: [RigUpgrade]) {
        self.bot = bot
        self.seed = seed
        self.rewardPool = rewardPool
        offered = Array(repeating: 0, count: rewardPool.count)
        taken = Array(repeating: 0, count: rewardPool.count)
        self.upgrades = upgrades
        upgradePicks = Array(repeating: 0, count: upgrades.count)
    }

    public func count(_ ending: Ending) -> Int {
        Ending.allCases.firstIndex(of: ending).map { endings[$0] } ?? 0
    }

    /// `part` of `whole` in tenths of a percent, rounded down.
    public static func perMille(_ part: Int, of whole: Int) -> Int {
        whole > 0 ? part * 1000 / whole : 0
    }

    /// `total / runs` in tenths, rounded down.
    public func averageTenths(_ total: Int) -> Int {
        runs > 0 ? total * 10 / runs : 0
    }
}
