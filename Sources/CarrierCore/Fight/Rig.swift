/// The player's cyberdeck as a fight sees it (kickoff §5).
public struct Rig: Codable, Sendable, Equatable {
    /// Cycles at the start of each turn (CPU).
    public var cycles: Int
    /// Daemon capacity.
    public var ram: Int
    public var handSize: Int
    public var maxHandSize: Int
    public var maxIntegrity: Int

    public init(cycles: Int, ram: Int, handSize: Int, maxHandSize: Int, maxIntegrity: Int) {
        self.cycles = cycles
        self.ram = ram
        self.handSize = handSize
        self.maxHandSize = maxHandSize
        self.maxIntegrity = maxIntegrity
    }

    /// The starting rig from `tuning.json`.
    public init(tuning: RigTuning) {
        self.init(
            cycles: tuning.cycles,
            ram: tuning.ram,
            handSize: tuning.handSize,
            maxHandSize: tuning.maxHandSize,
            maxIntegrity: tuning.integrity
        )
    }
}
