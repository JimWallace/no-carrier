/// Everything a player can do in a contract. A replay is a seed and a list
/// of these.
public enum ContractAction: Codable, Sendable, Equatable {
    /// Starts a fight on a node linked to one the player owns.
    case attack(node: Int)
    /// Cancels a CONTEST on one of the player's nodes.
    case reinforce(node: Int)
    /// Spends the action on nothing.
    case wait
    /// Spends the action, and Alert, to learn everything about a DETECTED
    /// node.
    case scan(node: Int)
    /// Ends the contract. It is a success only when the objective is done.
    case jackOut
    /// At the access choice: fight on and capture.
    case claim
    /// At the access choice: take access and leave the fight.
    case ghost
    /// An action inside the running fight.
    case fight(Action)
    /// Takes reward card `choice`. When Storage is full, `replacing` names
    /// the deck position of the card to delete for it; when it is not full,
    /// `replacing` is ignored.
    case takeReward(choice: Int, replacing: Int?)
    case skipReward
    case chooseUpgrade(choice: Int)
}
