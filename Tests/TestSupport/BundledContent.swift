import CarrierContent
public import CarrierCore

/// The content that ships, loaded once per test process.
public enum BundledContent {
    public static func load() throws -> ContentPack {
        try ContentLoader.loadBundled()
    }
}
