/// Everything a player can do in a contract. A replay is a seed and a list
/// of these.
public enum ContractAction: Codable, Sendable, Equatable {
    /// Starts a fight on a node linked to one the player owns.
    case attack(node: Int)
    /// Cancels a CONTEST on one of the player's nodes.
    case reinforce(node: Int)
    /// Spends the action on nothing.
    case wait
    /// An action inside the running fight.
    case fight(Action)
    /// Takes reward card `choice`. When Storage is full, `replacing` names
    /// the deck position of the card to delete for it.
    case takeReward(choice: Int, replacing: Int?)
    case skipReward
    case chooseUpgrade(choice: Int)
}
