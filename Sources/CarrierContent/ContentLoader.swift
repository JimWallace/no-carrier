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
        "cards.json", "ice.json", "os_families.json", "hardware.json", "orgs.json", "tuning.json",
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
        let pack = ContentPack(
            cards: try decode([CardDefinition].self, "cards.json", in: directory),
            ice: try decode([ICEDefinition].self, "ice.json", in: directory),
            osFamilies: try decode([OSFamily].self, "os_families.json", in: directory),
            hardware: try decode(HardwareCatalog.self, "hardware.json", in: directory),
            orgs: try decode([OrgTemplate].self, "orgs.json", in: directory),
            tuning: try decode(Tuning.self, "tuning.json", in: directory)
        )
        let errors = pack.validate()
        guard errors.isEmpty else { throw .invalidContent(errors) }
        return pack
    }

    private static func decode<T: Decodable>(
        _ type: T.Type, _ name: String, in directory: URL
    ) throws(ContentLoadError) -> T {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw .missingFile(name: name, directory: directory.path)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw .unreadable(name: name, reason: String(describing: error))
        }
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
