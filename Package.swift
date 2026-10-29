// swift-tools-version: 6.4
import PackageDescription

func swiftSettings(mainActorByDefault: Bool) -> [SwiftSetting] {
    var settings: [SwiftSetting] = [
        .treatAllWarnings(as: .error),
        .strictMemorySafety(),
        .unsafeFlags(["-warn-implicit-overrides", "-Xfrontend", "-warn-soft-deprecated"]),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]
    if mainActorByDefault {
        settings.append(.defaultIsolation(MainActor.self))
    }
    return settings
}

// swiftlint:disable:next prefixed_toplevel_constant - SwiftPM requires this exact name
let package = Package(
    name: "MinMaxCal",
    platforms: [.macOS(.v26), .iOS(.v26), .watchOS(.v26)],
    products: [
        .library(name: "MinMaxCalDomain", targets: ["MinMaxCalDomain"]),
        .library(name: "MinMaxCalData", targets: ["MinMaxCalData"]),
        .library(name: "MinMaxCalAgenda", targets: ["MinMaxCalAgenda"]),
        .library(name: "MinMaxCalFeatures", targets: ["MinMaxCalFeatures"]),
        .library(name: "MinMaxCalIntents", targets: ["MinMaxCalIntents"]),
        .library(name: "MinMaxCalCoachingData", targets: ["MinMaxCalCoachingData"]),
        .library(name: "MinMaxCalCoachingFeatures", targets: ["MinMaxCalCoachingFeatures"]),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio", exact: "0.17.7", traits: [])
    ],
    targets: [
        .target(name: "MinMaxCalDomain", swiftSettings: swiftSettings(mainActorByDefault: false)),
        .target(
            name: "MinMaxCalData",
            dependencies: ["MinMaxCalDomain"],
            swiftSettings: swiftSettings(mainActorByDefault: false),
        ),
        .target(
            name: "MinMaxCalAgenda",
            dependencies: ["MinMaxCalDomain", "MinMaxCalData"],
            swiftSettings: swiftSettings(mainActorByDefault: true),
        ),
        .target(
            name: "MinMaxCalFeatures",
            dependencies: [
                "MinMaxCalDomain", "MinMaxCalData", "MinMaxCalAgenda",
                .target(name: "MinMaxCalCoachingFeatures", condition: .when(platforms: [.macOS])),
            ],
            swiftSettings: swiftSettings(mainActorByDefault: true),
        ),
        .target(
            name: "MinMaxCalIntents",
            dependencies: ["MinMaxCalDomain", "MinMaxCalAgenda", "MinMaxCalFeatures"],
            swiftSettings: swiftSettings(mainActorByDefault: false),
            // Weak so AppIntents symbols absent from the running OS resolve
            // to null instead of preventing the test bundle from loading.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "AppIntents"])],
        ),
        .target(name: "MinMaxCalCoachingDomain", swiftSettings: swiftSettings(mainActorByDefault: false)),
        .target(
            name: "MinMaxCalCoachingData",
            dependencies: [
                "MinMaxCalCoachingDomain",
                .product(name: "FluidAudio", package: "FluidAudio", condition: .when(platforms: [.macOS])),
            ],
            swiftSettings: swiftSettings(mainActorByDefault: false),
        ),
        .target(
            name: "MinMaxCalCoachingFeatures",
            dependencies: ["MinMaxCalCoachingDomain", "MinMaxCalDomain", "MinMaxCalAgenda"],
            swiftSettings: swiftSettings(mainActorByDefault: true),
        ),
        .testTarget(
            name: "MinMaxCalCoachingDomainTests",
            dependencies: ["MinMaxCalCoachingDomain"],
            swiftSettings: swiftSettings(mainActorByDefault: false),
        ),
        .testTarget(
            name: "MinMaxCalCoachingDataTests",
            dependencies: ["MinMaxCalCoachingData"],
            swiftSettings: swiftSettings(mainActorByDefault: false),
        ),
        .testTarget(
            name: "MinMaxCalCoachingFeaturesTests",
            dependencies: ["MinMaxCalCoachingFeatures"],
            swiftSettings: swiftSettings(mainActorByDefault: true),
        ),
        .testTarget(
            name: "MinMaxCalDomainTests",
            dependencies: ["MinMaxCalDomain"],
            swiftSettings: swiftSettings(mainActorByDefault: false),
        ),
        .testTarget(
            name: "MinMaxCalDataTests",
            dependencies: ["MinMaxCalData"],
            swiftSettings: swiftSettings(mainActorByDefault: false),
        ),
        .testTarget(
            name: "MinMaxCalFeaturesTests",
            dependencies: ["MinMaxCalAgenda", "MinMaxCalFeatures", "MinMaxCalIntents"],
            swiftSettings: swiftSettings(mainActorByDefault: true),
        ),
    ],
    swiftLanguageModes: [.v6],
)

for target in package.targets {
    target.linkerSettings = (target.linkerSettings ?? []) + [
        .unsafeFlags(["-Xlinker", "-fatal_warnings"]),
        .unsafeFlags(["-Xlinker", "-warn_unused_dylibs"]),
        .unsafeFlags(["-Xlinker", "-warn_duplicate_libraries"]),
    ]
}
