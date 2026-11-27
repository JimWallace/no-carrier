/// What the contract is waiting for.
public enum ContractPhase: Codable, Sendable, Equatable {
    /// The network map: ATTACK, REINFORCE or WAIT.
    case map
    /// A node fight is running.
    case fight(node: Int, state: FightState, deck: [String])
    /// A DATA node was captured: choose an upgrade, then take the reward.
    case upgrade(node: Int, choices: [RigUpgrade], reward: [String])
    /// A node was captured: take one card or skip.
    case reward(node: Int, choices: [String])
    case over(ContractOutcome)
}
