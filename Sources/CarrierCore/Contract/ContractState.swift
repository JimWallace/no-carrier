/// The whole state of one contract (kickoff §2, layer 2). Value type: the
/// contract engine returns a new one for every action.
public struct ContractState: Codable, Sendable, Equatable {
    public var seed: UInt64
    public var network: Network
    /// Card ids, the persistent deck between fights.
    public var deck: [String]
    public var rig: Rig
    /// The deck size cap (kickoff §5).
    public var storage: Int
    /// Network actions per tick (the modem).
    public var bandwidth: Int
    public var integrity: Int
    public var trace: Int
    public var tick: Int
    public var actionsLeft: Int
    /// Announced last tick; resolves at the end of this one.
    public var sysopIntent: SysopIntent?
    public var phase: ContractPhase
    public var fightsStarted: Int
    public var rng: Xoshiro256StarStar
    public var objective: ObjectiveDefinition
    public var alert: Int
    /// The Alert state, which stays ACTIVE once reached.
    public var alertState: AlertState
    /// Alert added by noise this tick; a quiet tick lets Alert decay.
    public var noiseThisTick: Int
    /// The player chose CLAIM in the running fight, so it is not asked again.
    public var claimChosen: Bool

    public init(
        seed: UInt64, network: Network, deck: [String], rig: Rig, storage: Int, bandwidth: Int,
        integrity: Int, trace: Int, rng: Xoshiro256StarStar, objective: ObjectiveDefinition, alertState: AlertState
    ) {
        self.seed = seed
        self.network = network
        self.deck = deck
        self.rig = rig
        self.storage = storage
        self.bandwidth = bandwidth
        self.integrity = integrity
        self.trace = trace
        tick = 1
        actionsLeft = bandwidth
        sysopIntent = nil
        phase = .map
        fightsStarted = 0
        self.rng = rng
        self.objective = objective
        alert = objective.startAlert
        self.alertState = alertState
        noiseThisTick = 0
        claimChosen = false
    }

    public var outcome: ContractOutcome? {
        if case .over(let outcome) = phase { return outcome }
        return nil
    }

    /// The running fight, when there is one.
    public var fight: FightState? {
        switch phase {
        case .fight(_, let state, _), .accessChoice(_, let state, _): state
        default: nil
        }
    }
}
