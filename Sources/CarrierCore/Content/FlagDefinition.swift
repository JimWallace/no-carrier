/// One entry of `flags.json`: what a flag is, where it lives, and what it
/// needs (addendum 02, §1). Names are kept as text so that validation can
/// report a name this build does not know.
public struct FlagDefinition: Codable, Sendable, Equatable {
    public var name: String
    public var description: String
    /// The base layer's value.
    public var `default`: Bool
    public var category: FlagCategory
    /// Flags that must be on whenever this one is (paired mechanics, §1).
    public var requires: [String]

    public init(name: String, description: String, default: Bool, category: FlagCategory, requires: [String] = []) {
        self.name = name
        self.description = description
        self.default = `default`
        self.category = category
        self.requires = requires
    }

    private enum CodingKeys: String, CodingKey {
        case name, description, `default`, category, requires
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        self.default = try container.decode(Bool.self, forKey: .default)
        category = try container.decode(FlagCategory.self, forKey: .category)
        requires = try container.decodeIfPresent([String].self, forKey: .requires) ?? []
    }

    /// The flag this entry describes, or nil for a name this build does
    /// not know.
    public var flag: MechanicFlag? { MechanicFlag(rawValue: name) }
}
