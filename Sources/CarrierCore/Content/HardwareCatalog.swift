/// The CPUs and modems a machine can have (kickoff §6, "Hardware").
public struct HardwareCatalog: Codable, Sendable, Equatable {
    public var cpus: [CPUModel]
    public var modems: [ModemModel]
}

public struct CPUModel: Codable, Sendable, Equatable {
    public var name: String
    /// 1 to 3. `Tuning.cpuTiers` says what each tier does to ICE.
    public var tier: Int
}

public struct ModemModel: Codable, Sendable, Equatable {
    public var name: String
    /// The multiplier on ICE TRACE intents, as a percent (150 = x1.5).
    public var tracePercent: Int
}
