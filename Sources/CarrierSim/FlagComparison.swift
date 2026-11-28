public import CarrierCore
public import CarrierGen

/// `carrier sim --compare <flag>` (addendum 02, §1): the same seeds played
/// with one flag on and then off, every other rule the same.
public struct FlagComparison: Sendable, Equatable {
    public let flag: MechanicFlag
    public let on: SimulationReport
    public let off: SimulationReport

    public init(flag: MechanicFlag, on: SimulationReport, off: SimulationReport) {
        self.flag = flag
        self.on = on
        self.off = off
    }

    /// Plays the same seeds with `on` and `off`, two simulations whose
    /// rules differ only in `flag`. The caller composes and checks both.
    public static func run(
        _ flag: MechanicFlag, on: Simulation, off: Simulation, runs: Int, seed: UInt64,
        makeBot: (UInt64) -> any ContractBot
    ) throws(GenerationError) -> Self {
        Self(
            flag: flag, on: try on.run(runs: runs, seed: seed, makeBot: makeBot),
            off: try off.run(runs: runs, seed: seed, makeBot: makeBot))
    }
}
