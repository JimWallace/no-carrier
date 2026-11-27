/// A kind of organisation that owns machines (kickoff §6, "Hostname / org").
public struct OrgTemplate: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var label: String
    /// The name is one word from `firstNames` and one from `secondNames`.
    public var firstNames: [String]
    public var secondNames: [String]
    public var topLevelDomain: String
    /// Host names; `{n}` becomes a two-digit number.
    public var hosts: [String]
    public var users: [String]
    public var files: [String]
}
