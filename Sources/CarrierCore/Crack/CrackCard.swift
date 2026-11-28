/// A program in the crack prototype. For now a card is one symbol.
public struct CrackCard: Codable, Sendable, Equatable {
    public let id: String
    public let symbol: String

    public init(id: String, symbol: String) {
        self.id = id
        self.symbol = symbol
    }
}
