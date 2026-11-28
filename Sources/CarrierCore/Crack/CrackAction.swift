/// What the player can do in the crack prototype. Hand indices and slots
/// count from 0.
public enum CrackAction: Codable, Sendable, Equatable {
    /// A card from the hand onto a board slot. A card already in the slot
    /// goes to the discard pile.
    case place(handIndex: Int, slot: Int)
    /// Two board slots trade places.
    case swap(Int, Int)
    /// A card from the hand onto the discard pile, to make room.
    case drop(handIndex: Int)
    /// Submits the board as a guess; it ends the turn.
    case guess
    case logout
}
