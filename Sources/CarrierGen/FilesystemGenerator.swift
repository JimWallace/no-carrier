public import CarrierCore

/// A machine's disk, for flavour (kickoff §6, "Filesystems"): the OS
/// family's fixed paths, a few user homes and a few of the org's own files.
public enum FilesystemGenerator {
    public struct Result: Sendable, Equatable {
        public var users: [String]
        public var paths: [String]
    }

    public static func generate(
        seed: UInt64,
        template: FilesystemTemplate,
        org: OrgTemplate,
        orgName: String,
        tuning: FilesystemTuning
    ) throws(GenerationError) -> Result {
        var rng = Xoshiro256StarStar(seed: seed)
        let shortOrg = shortName(orgName)

        var users = org.users
        rng.shuffle(&users)
        let homeCount = min(users.count, rng.nextInt(in: tuning.homes.min...tuning.homes.max))
        users = Array(users.prefix(homeCount)).sorted()

        var files = org.files
        rng.shuffle(&files)
        let fileCount = min(files.count, rng.nextInt(in: tuning.orgFiles.min...tuning.orgFiles.max))
        files = Array(files.prefix(fileCount)).sorted()

        let orgDir = fill(template.orgDir, user: "", shortOrg: shortOrg, orgName: orgName)
        var paths = template.fixed
        paths += users.map { fill(template.home, user: $0, shortOrg: shortOrg, orgName: orgName) }
        paths.append(orgDir)
        paths += files.map { orgDir + (template.upperCaseFiles ? dosName($0) : $0) }
        return Result(users: users, paths: paths)
    }

    /// Fills `{user}`, `{USER}`, `{org}`, `{ORG}` (the 8-letter short name)
    /// and `{Org}` (the full name in title case).
    static func fill(_ pattern: String, user: String, shortOrg: String, orgName: String) -> String {
        pattern
            .replacing("{user}", with: user)
            .replacing("{USER}", with: user.uppercased())
            .replacing("{org}", with: shortOrg.lowercased())
            .replacing("{ORG}", with: shortOrg)
            .replacing("{Org}", with: titleCase(orgName))
    }

    /// `FIRST CONTINENTAL SAVINGS` becomes `First Continental Savings`.
    static func titleCase(_ text: String) -> String {
        text.split(separator: " ").map { word in
            word.prefix(1).uppercased() + word.dropFirst().lowercased()
        }.joined(separator: " ")
    }

    /// The org's name, letters only, at most 8 characters: an 8.3-safe
    /// directory name (`FIRST CONTINENTAL TRUST` becomes `FIRSTCON`).
    static func shortName(_ orgName: String) -> String {
        String(orgName.filter(\.isLetter).uppercased().prefix(8))
    }

    /// An 8.3 file name: `thesis_final.tex` becomes `THESIS~1.TEX`.
    public static func dosName(_ name: String) -> String {
        let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
        let stem = (parts.first ?? name).uppercased()
        let ext = parts.count > 1 ? String(parts[1].uppercased().prefix(3)) : ""
        let shortStem = stem.count > 8 ? String(stem.prefix(6)) + "~1" : stem
        return ext.isEmpty ? shortStem : "\(shortStem).\(ext)"
    }
}
