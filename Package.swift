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
        .macOS("13.0")
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
        // Bots and the headless simulation behind `carrier sim` (M4). Pure,
        // like CarrierCore: the same seed gives the same report.
        .target(
            name: "CarrierSim",
            dependencies: ["CarrierCore", "CarrierGen"],
            path: "Sources/CarrierSim",
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
        // The terminal frontend's pure parts: the 40-column renderers, the
        // command parsers and the play and fight sessions. `carrier` and the
        // MCP server both draw the screen with them, so a human and an MCP
        // client see the same game.
        .target(
            name: "CarrierTerminal",
            dependencies: ["CarrierCore"],
            path: "Sources/CarrierTerminal",
            swiftSettings: sourceSettings
        ),
        // The MCP server behind `carrier mcp`: JSON-RPC 2.0 over stdio, and
        // game tools that drive the contract and fight engines. It only
        // sends actions and renders events; it holds no rule.
        .target(
            name: "CarrierMCP",
            dependencies: ["CarrierCore", "CarrierGen", "CarrierTerminal"],
            path: "Sources/CarrierMCP",
            swiftSettings: sourceSettings
        ),
        .executableTarget(
            name: "carrier-cli",
            dependencies: [
                "CarrierCore",
                "CarrierGen",
                "CarrierSim",
                "CarrierContent",
                "CarrierTerminal",
                "CarrierMCP",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/carrier-cli",
            swiftSettings: sourceSettings
        ),
        // Helpers shared by the test targets: the golden-snapshot compare and
        // the bundled content.
        .target(
            name: "TestSupport",
            dependencies: ["CarrierCore", "CarrierGen", "CarrierContent"],
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
        .testTarget(
            name: "CarrierSimTests",
            dependencies: ["CarrierCore", "CarrierGen", "CarrierSim", "TestSupport"],
            path: "Tests/CarrierSimTests",
            swiftSettings: sourceSettings
        ),
        // The terminal frontend's pure parts: the command parser, the line
        // editor and the 40-column layout.
        .testTarget(
            name: "CarrierCLITests",
            dependencies: ["carrier-cli", "CarrierTerminal", "CarrierCore", "TestSupport"],
            path: "Tests/CarrierCLITests",
            swiftSettings: sourceSettings
        ),
        // The MCP server: framing, tools, the fog and replays.
        .testTarget(
            name: "CarrierMCPTests",
            dependencies: ["CarrierCore", "CarrierGen", "CarrierMCP", "TestSupport"],
            path: "Tests/CarrierMCPTests",
            swiftSettings: sourceSettings
        ),
    ]
)
