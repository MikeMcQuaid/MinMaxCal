// swift-tools-version: 6.4
import PackageDescription

func swiftSettings(mainActorByDefault: Bool) -> [SwiftSetting] {
    var settings: [SwiftSetting] = [
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
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "MinMaxCalDomain", targets: ["MinMaxCalDomain"]),
        .library(name: "MinMaxCalData", targets: ["MinMaxCalData"]),
        .library(name: "MinMaxCalFeatures", targets: ["MinMaxCalFeatures"]),
    ],
    targets: [
        .target(name: "MinMaxCalDomain", swiftSettings: swiftSettings(mainActorByDefault: false)),
        .target(
            name: "MinMaxCalData",
            dependencies: ["MinMaxCalDomain"],
            swiftSettings: swiftSettings(mainActorByDefault: false),
        ),
        .target(
            name: "MinMaxCalFeatures",
            dependencies: ["MinMaxCalDomain", "MinMaxCalData"],
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
            dependencies: ["MinMaxCalFeatures"],
            swiftSettings: swiftSettings(mainActorByDefault: true),
        ),
    ],
    swiftLanguageModes: [.v6],
)
