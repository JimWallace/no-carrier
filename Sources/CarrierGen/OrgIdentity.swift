public import CarrierCore

/// One organisation: its template and the name drawn for it.
public struct OrgIdentity: Codable, Sendable, Equatable {
    public var template: OrgTemplate
    /// The first part of the name, which the domain is made from.
    public var firstName: String
    public var name: String

    public init(template: OrgTemplate, firstName: String, name: String) {
        self.template = template
        self.firstName = firstName
        self.name = name
    }
}
