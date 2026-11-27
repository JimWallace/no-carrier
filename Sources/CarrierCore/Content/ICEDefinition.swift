/// An ICE program: a fixed cycle of steps, each a list of intents that it
/// carries out together (BLACKICE: ATTACK 8, then ATTACK 5 + HARDEN 3).
public struct ICEDefinition: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var pattern: [[Intent]]

    public init(id: String, name: String, pattern: [[Intent]]) {
        self.id = id
        self.name = name
        self.pattern = pattern
    }
}
