public import CarrierCore

/// Builds a `Machine` from a seed (kickoff §6). The same seed, role and
/// content always give the same machine: every choice is a draw from one
/// PRNG, in a fixed order, and the filesystem uses a child seed of its own so
/// that it can be generated lazily without moving any other draw.
public struct MachineGenerator: Sendable {
    public let content: ContentPack

    public init(content: ContentPack) {
        self.content = content
    }

    public func generate(seed: UInt64, role: NodeRole) throws(GenerationError) -> Machine {
        var rng = Xoshiro256StarStar(seed: seed)
        let roleTuning = content.tuning.roles[role]

        let org = try rng.choose(content.orgs, "orgs")
        let firstName = try rng.choose(org.firstNames, "\(org.id).firstNames")
        let orgName = firstName + " " + (try rng.choose(org.secondNames, "\(org.id).secondNames"))
        let hostname = try makeHostname(org: org, firstName: firstName, rng: &rng)

        let familyID = try rng.choose(roleTuning.osFamilies, "roles.\(role.rawValue).osFamilies")
        guard let family = content.osFamily(familyID) else {
            throw .unknownReference(field: "roles.\(role.rawValue).osFamilies", name: familyID)
        }
        let version = try rng.choose(family.versions, "\(family.id).versions")
        let cpuName = try rng.choose(family.cpus, "\(family.id).cpus")
        guard let cpu = content.cpu(named: cpuName) else {
            throw .unknownReference(field: "\(family.id).cpus", name: cpuName)
        }
        let ramMB = try rng.choose(roleTuning.ramMB, "roles.\(role.rawValue).ramMB")
        let modemName = try rng.choose(roleTuning.modems, "roles.\(role.rawValue).modems")
        guard let modem = content.modem(named: modemName) else {
            throw .unknownReference(field: "roles.\(role.rawValue).modems", name: modemName)
        }

        let layers = makeLayers(roleTuning: roleTuning, ramMB: ramMB, rng: &rng)
        let ice = try makeICE(roleTuning: roleTuning, role: role, ramMB: ramMB, rng: &rng)

        let filesystem = try FilesystemGenerator.generate(
            seed: Seed.derive(seed, "filesystem"),
            template: family.filesystem,
            org: org,
            orgName: orgName,
            tuning: content.tuning.filesystem
        )

        return Machine(
            seed: seed,
            role: role,
            orgName: orgName,
            orgKind: org.label,
            hostname: hostname,
            osFamilyID: family.id,
            osName: family.name,
            osVersion: version,
            cpu: cpu,
            ramMB: ramMB,
            modem: modem,
            weak: family.weak,
            resist: family.resist,
            layers: layers,
            ice: ice,
            users: filesystem.users,
            filesystem: filesystem.paths
        )
    }

    /// `host.domain.tld`, where the domain is the first part of the org's
    /// name with everything but letters removed: `vault02.meridian.com`.
    private func makeHostname(
        org: OrgTemplate, firstName: String, rng: inout Xoshiro256StarStar
    ) throws(GenerationError) -> String {
        let host = try rng.choose(org.hosts, "\(org.id).hosts")
        let number = rng.nextInt(in: 1...12)
        let filledHost = host.replacing("{n}", with: number < 10 ? "0\(number)" : "\(number)")
        let domain = String(firstName.lowercased().filter(\.isLetter))
        return "\(filledHost).\(domain).\(org.topLevelDomain)"
    }

    /// FIREWALL and AUTH, plus KERNEL for sysop and ROOT machines. Each
    /// layer rolls its range and gains one HP per `ramPerLayerHP` MB.
    private func makeLayers(
        roleTuning: RoleTuning, ramMB: Int, rng: inout Xoshiro256StarStar
    ) -> [SecurityLayer] {
        let bonus = ramMB / content.tuning.ice.ramPerLayerHP
        var ranges: [(LayerKind, HPRange)] = [(.firewall, roleTuning.firewall), (.auth, roleTuning.auth)]
        if let kernel = roleTuning.kernel {
            ranges.append((.kernel, kernel))
        }
        return ranges.map { kind, range in
            SecurityLayer(kind: kind, hp: rng.nextInt(in: range.min...range.max) + bonus)
        }
    }

    /// 1 + RAM / 24 programs, at most 3 (kickoff §6), drawn from the role's
    /// pool with repeats allowed.
    private func makeICE(
        roleTuning: RoleTuning, role: NodeRole, ramMB: Int, rng: inout Xoshiro256StarStar
    ) throws(GenerationError) -> [String] {
        let tuning = content.tuning.ice
        let count = min(tuning.max, tuning.base + ramMB / tuning.ramPerExtra)
        var programs: [String] = []
        for _ in 0..<count {
            programs.append(try rng.choose(roleTuning.icePool, "roles.\(role.rawValue).icePool"))
        }
        return programs
    }
}
