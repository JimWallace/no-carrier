// swift-tools-version:6.4
import PackageDescription

let strictWarnings: [SwiftSetting] = [.treatAllWarnings(as: .error)]

// Upcoming language features that every target uses now. Each one is the
// default in a future language mode.
//
// - ExistentialAny: an existential type is written `any P`.
// - MemberImportVisibility: a file uses only the members of the modules that
//   it imports itself, not those that another file imports.
// - InternalImportsByDefault: an `import` is internal. A file whose public API
//   shows a type from another module writes `public import`.
// - InferIsolatedConformances: a conformance of an actor-isolated type has that
//   isolation.
// - ImmutableWeakCaptures: a `weak` capture is a `let`.
let sourceSettings: [SwiftSetting] =
    strictWarnings + [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("ImmutableWeakCaptures"),
        // Strict memory safety (SE-0458): each unsafe construct needs an
        // explicit `unsafe` mark, and `strictWarnings` makes a missing mark a
        // build error.
        .strictMemorySafety(),
    ]

let package = Package(
    name: "NoCarrier",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .executable(name: "carrier", targets: ["carrier-cli"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
        // SwiftLint via SimplyDanny's plugin distribution: ships a pre-built
        // binary, so CI and fresh checkouts do not build SwiftLint from source.
        // Invoked on demand by `scripts/swiftlint.sh`; no `plugins:` entry on
        // any target, so `swift build` and `swift test` are unaffected.
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.65.1"),
    ],
    targets: [
        // Rules, state, actions, events and the seeded PRNG. No I/O and no
        // Foundation: scripts/check-core-purity.sh enforces it.
        .target(
            name: "CarrierCore",
            path: "Sources/CarrierCore",
            swiftSettings: sourceSettings
        ),
        // Procedural generation: machines, hardware, orgs, filesystems. Pure,
        // like CarrierCore.
        .target(
            name: "CarrierGen",
            dependencies: ["CarrierCore"],
            path: "Sources/CarrierGen",
            swiftSettings: sourceSettings
        ),
        // Reads the content JSON (cards, ICE, OS families, hardware, orgs,
        // tuning) into a CarrierCore `ContentPack`. The only library target
        // that does file I/O.
        .target(
            name: "CarrierContent",
            dependencies: ["CarrierCore"],
            path: "Sources/CarrierContent",
            resources: [.copy("Content")],
            swiftSettings: sourceSettings
        ),
        .executableTarget(
            name: "carrier-cli",
            dependencies: [
                "CarrierCore",
                "CarrierGen",
                "CarrierContent",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/carrier-cli",
            swiftSettings: sourceSettings
        ),
        // Helpers shared by the test targets: the golden-snapshot compare and
        // the bundled content.
        .target(
            name: "TestSupport",
            dependencies: ["CarrierCore", "CarrierContent"],
            path: "Tests/TestSupport",
            swiftSettings: sourceSettings
        ),
        .testTarget(
            name: "CarrierCoreTests",
            dependencies: ["CarrierCore", "CarrierGen", "CarrierContent", "TestSupport"],
            path: "Tests/CarrierCoreTests",
            exclude: ["Snapshots"],
            swiftSettings: sourceSettings
        ),
        .testTarget(
            name: "CarrierGenTests",
            dependencies: ["CarrierCore", "CarrierGen", "CarrierContent", "TestSupport"],
            path: "Tests/CarrierGenTests",
            exclude: ["Snapshots"],
            swiftSettings: sourceSettings
        ),
    ]
)
