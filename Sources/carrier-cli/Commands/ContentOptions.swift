import ArgumentParser
import CarrierContent
import CarrierCore
import Foundation

/// `--content <dir>`: play with a copy of the content JSON instead of the
/// bundled files, so a playtester can tune without a rebuild.
struct ContentOptions: ParsableArguments {
    @Option(name: .long, help: "A directory of content JSON to use instead of the bundled content.")
    var content: String?

    func load() throws -> ContentPack {
        do {
            if let content {
                return try ContentLoader.load(from: URL(fileURLWithPath: content, isDirectory: true))
            }
            return try ContentLoader.loadBundled()
        } catch {
            throw ValidationError("content: \(error.description)")
        }
    }
}

/// `--seed <n>`: decimal, or hex with `0x`. Without it, a fresh seed is drawn
/// and printed, so any session can be reproduced.
struct SeedOption: ParsableArguments {
    @Option(name: .long, help: "The seed: decimal, or hex with 0x. Random when omitted.")
    var seed: String?

    func resolve() throws -> UInt64 {
        guard let seed else {
            // The CLI is not pure; only the core must be. The seed it draws
            // here is printed, so the session can be replayed.
            return UInt64.random(in: 0...UInt64.max)
        }
        guard let value = Seed.parse(seed) else {
            throw ValidationError("--seed: \"\(seed)\" is not a decimal or 0x hex number")
        }
        return value
    }
}

/// `--objective <id>`: which objective a contract has. Without it, the first
/// in `objectives.json` (TAKEOVER).
struct ObjectiveOption: ParsableArguments {
    @Option(name: .long, help: "The contract objective, by id (see objectives.json). Default: takeover.")
    var objective: String?

    func resolve(_ content: ContentPack) throws -> ObjectiveDefinition {
        try Self.find(objective, in: content)
    }

    static func find(_ id: String?, in content: ContentPack) throws -> ObjectiveDefinition {
        if let id {
            guard let found = content.objective(id.lowercased()) else {
                let known = content.objectives.map(\.id).joined(separator: ", ")
                throw ValidationError("--objective: \"\(id)\" is not one of \(known)")
            }
            return found
        }
        guard let first = content.defaultObjective else { throw ValidationError("content: no objectives") }
        return first
    }
}
