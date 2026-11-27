/// An ICE program: a fixed cycle of steps, each a list of intents that it
/// carries out together (BLACKICE: ATTACK 8, then ATTACK 5 + HARDEN 3).
///
/// A boss (THE OPERATOR) has a second pattern, `phaseTwo`, that takes over
/// from the start once the machine is down to its KERNEL.
public struct ICEDefinition: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var pattern: [[Intent]]
    public var phaseTwo: [[Intent]]?

    public init(id: String, name: String, pattern: [[Intent]], phaseTwo: [[Intent]]? = nil) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.phaseTwo = phaseTwo
    }
}
