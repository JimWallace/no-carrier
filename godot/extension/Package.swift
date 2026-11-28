// swift-tools-version:6.4
import PackageDescription

// The Godot frontend: a GDExtension library that draws the map and the
// fight in Godot and drives the same pure engine as `carrier`. It is its own
// package so that the main package never builds SwiftGodot.
//
// Run godot/scripts/build.sh, not `swift build` here: it fetches the pinned
// SwiftGodot into vendor/ first (see godot/scripts/fetch-swiftgodot.sh).
//
// macOS 14 is SwiftGodot's floor: its signal types use parameter packs in
// generic types, which need the Swift runtime in macOS 14.

// The same settings as the main package's `sourceSettings`.
let sourceSettings: [SwiftSetting] = [
    .treatAllWarnings(as: .error),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
    // Strict memory safety (SE-0458), as in the main package.
    .strictMemorySafety(),
]

let package = Package(
    name: "CarrierGodot",
    platforms: [
        .macOS("14.0")
    ],
    products: [
        .library(name: "CarrierGodot", type: .dynamic, targets: ["CarrierGodot"])
    ],
    dependencies: [
        .package(name: "NoCarrier", path: "../.."),
        .package(name: "SwiftGodot", path: "vendor/SwiftGodot"),
    ],
    targets: [
        .target(
            name: "CarrierGodot",
            dependencies: [
                .product(name: "CarrierEngine", package: "NoCarrier"),
                .product(name: "SwiftGodotStatic", package: "SwiftGodot"),
            ],
            path: "Sources/CarrierGodot",
            swiftSettings: sourceSettings
        )
    ]
)
