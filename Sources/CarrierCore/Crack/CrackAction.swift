/// What the player can do in the crack prototype. Hand indices and slots
/// count from 0.
public enum CrackAction: Codable, Sendable, Equatable {
    /// A card from the hand used on a board slot. A symbol or dial card
    /// goes onto the slot, and a card already there goes to the discard
    /// pile. A probe reveals the slot's symbol in the code.
    case play(handIndex: Int, slot: Int)
    /// The dial in `slot` turned to show `symbol`.
    case turn(slot: Int, symbol: String)
    /// Two board slots trade places.
    case swap(Int, Int)
    /// A card from the hand onto the discard pile, to make room.
    case drop(handIndex: Int)
    /// Submits the board as a guess; it ends the turn.
    case guess
    case logout
}
