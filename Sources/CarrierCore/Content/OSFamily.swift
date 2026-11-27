/// An operating-system family (kickoff §6). Names are allusive, never real.
public struct OSFamily: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var versions: [String]
    public var weak: [ExploitTag]
    public var resist: [ExploitTag]
    /// The CPU names (from `HardwareCatalog.cpus`) this family runs on.
    public var cpus: [String]
    public var filesystem: FilesystemTemplate
}

/// How an OS family lays out its disk. Paths may hold the tokens `{user}`,
/// `{USER}`, `{org}`, `{ORG}` and `{Org}`; `CarrierGen` fills them in.
public struct FilesystemTemplate: Codable, Sendable, Equatable {
    /// Paths every machine of the family has.
    public var fixed: [String]
    /// One path per user account.
    public var home: String
    /// The directory that holds the organisation's own files. It ends in
    /// the family's separator, so a file path is `orgDir` + the file name.
    public var orgDir: String
    /// Upper-cases file names (8.3-style systems).
    public var upperCaseFiles: Bool
}
