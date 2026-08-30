/// An installed app that opens call links, by bundle identifier, with the name Settings shows.
public struct JoinApp: Hashable, Sendable {
    // MARK: Lifecycle

    public init(bundleIdentifier: String, name: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }

    // MARK: Public

    public static let edge: Self = .init(bundleIdentifier: "com.microsoft.edgemac", name: "Microsoft Edge")
    public static let facetime: Self = .init(bundleIdentifier: "com.apple.FaceTime", name: "FaceTime")
    public static let teams: Self = .init(bundleIdentifier: "com.microsoft.teams2", name: "Microsoft Teams")
    public static let zoom: Self = .init(bundleIdentifier: "us.zoom.xos", name: "Zoom")

    public let bundleIdentifier: String
    public let name: String
}
