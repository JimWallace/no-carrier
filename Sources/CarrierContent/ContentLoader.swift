public import CarrierCore
public import Foundation

/// Reads the content JSON into a validated `ContentPack`.
///
/// The bundled content is in `Content/` beside this file. A playtester can
/// point `carrier fight --content <dir>` (or `gen`) at a copy of that folder to tune without
/// a rebuild.
public enum ContentLoader {
    /// The file names a content directory holds.
    public static let fileNames = [
        "cards.json", "ice.json", "os_families.json", "hardware.json", "orgs.json", "tuning.json", "maps.json",
        "objectives.json", "flags.json",
    ]

    /// The content that ships with this build.
    public static func loadBundled() throws(ContentLoadError) -> ContentPack {
        guard let directory = bundledDirectory else { throw .missingBundle }
        return try load(from: directory)
    }

    /// The bundled content directory, for copying it to tune.
    public static var bundledDirectory: URL? {
        Bundle.module.url(forResource: "Content", withExtension: nil)
    }

    public static func load(from directory: URL) throws(ContentLoadError) -> ContentPack {
        try load(source: directory.path) { name throws(ContentLoadError) in
            let url = directory.appendingPathComponent(name)
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                throw .missingFile(name: name, directory: directory.path)
            }
            do {
                return try Data(contentsOf: url)
            } catch {
                throw .unreadable(name: name, reason: String(describing: error))
            }
        }
    }

    /// Reads each file in `fileNames` with `read`, for a frontend that
    /// keeps the content somewhere other than a directory (the Godot
    /// frontend reads it from its project). `read` returns nil for a
    /// missing file; `source` names the place in that error.
    public static func load(
        source: String, read: (String) throws(ContentLoadError) -> Data?
    ) throws(ContentLoadError) -> ContentPack {
        func decode<T: Decodable>(_ type: T.Type, _ name: String) throws(ContentLoadError) -> T {
            guard let data = try read(name) else { throw .missingFile(name: name, directory: source) }
            return try decodeJSON(type, name, from: data)
        }
        let pack = ContentPack(
            cards: try decode([CardDefinition].self, "cards.json"),
            ice: try decode([ICEDefinition].self, "ice.json"),
            osFamilies: try decode([OSFamily].self, "os_families.json"),
            hardware: try decode(HardwareCatalog.self, "hardware.json"),
            orgs: try decode([OrgTemplate].self, "orgs.json"),
            tuning: try decode(Tuning.self, "tuning.json"),
            maps: try decode([MapTemplate].self, "maps.json"),
            objectives: try decode([ObjectiveDefinition].self, "objectives.json"),
            flags: try decode([FlagDefinition].self, "flags.json")
        )
        let errors = pack.validate()
        guard errors.isEmpty else { throw .invalidContent(errors) }
        return pack
    }

    private static func decodeJSON<T: Decodable>(
        _ type: T.Type, _ name: String, from data: Data
    ) throws(ContentLoadError) -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw .invalidJSON(name: name, reason: describe(error))
        } catch {
            throw .invalidJSON(name: name, reason: String(describing: error))
        }
    }

    /// A one-line reason with the JSON path, for a playtester editing a file.
    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            let keys = context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }
            return keys.joined()
        }
        switch error {
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            return "\(path(context)): \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "\(path(context)): missing key \"\(key.stringValue)\""
        @unknown default:
            return String(describing: error)
        }
    }
}
