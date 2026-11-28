/// A card on the board and the symbol it shows now. A dial can show a
/// symbol other than its printed one.
public struct CrackSlot: Codable, Sendable, Equatable {
    public let card: CardInstance
    public internal(set) var symbol: String

    public init(card: CardInstance, symbol: String) {
        self.card = card
        self.symbol = symbol
    }
}
