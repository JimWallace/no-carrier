/// One physical card in a fight. `uid` tells apart two copies of the same
/// card; `cardID` points at its `CardDefinition`.
public struct CardInstance: Codable, Sendable, Equatable {
    public let uid: Int
    public let cardID: String

    public init(uid: Int, cardID: String) {
        self.uid = uid
        self.cardID = cardID
    }
}
