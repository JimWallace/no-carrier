/// What the player can do in a run.
public enum CrackRunAction: Codable, Sendable, Equatable {
    /// An action in the crack under way.
    case crack(CrackAction)
    /// At a reward: add offered card number `index` (from 0) to the deck.
    case take(Int)
    /// At a reward: remove deck card number `index` (from 0) instead.
    case remove(Int)
    /// At a reward: take nothing.
    case skip
}
