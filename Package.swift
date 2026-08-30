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
        .library(name: "MinMaxCalIntents", targets: ["MinMaxCalIntents"]),
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
        .target(
            name: "MinMaxCalIntents",
            dependencies: ["MinMaxCalDomain", "MinMaxCalFeatures"],
            swiftSettings: swiftSettings(mainActorByDefault: false),
            // Weak so the test bundle still loads on a macOS older than the
            // deployment target, as CI's runner is: AppIntents symbols the
            // running OS lacks resolve to null instead of failing `dlopen`.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "AppIntents"])],
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
            dependencies: ["MinMaxCalFeatures", "MinMaxCalIntents"],
            swiftSettings: swiftSettings(mainActorByDefault: true),
        ),
    ],
    swiftLanguageModes: [.v6],
)
