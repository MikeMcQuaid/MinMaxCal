/// The app each call service's links open in, by bundle identifier; nil is the default browser.
public struct JoinSettings: Codable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(
        zoom: String? = nil,
        teams: String? = nil,
        meet: String? = nil,
        jitsi: String? = nil,
        facetime: String? = nil,
        other: String? = nil,
    ) {
        self.zoom = zoom
        self.teams = teams
        self.meet = meet
        self.jitsi = jitsi
        self.facetime = facetime
        self.other = other
    }

    // MARK: Public

    public var zoom: String?
    public var teams: String?
    public var meet: String?
    public var jitsi: String?
    public var facetime: String?
    public var other: String?

    /// Each service's own app, Edge for the web-only services and, when Teams is not installed, for
    /// Teams too.
    public static func `default`(teamsInstalled: Bool = true) -> Self {
        .init(
            zoom: JoinApp.zoom.bundleIdentifier,
            teams: (teamsInstalled ? JoinApp.teams : JoinApp.edge).bundleIdentifier,
            meet: JoinApp.edge.bundleIdentifier,
            jitsi: JoinApp.edge.bundleIdentifier,
            facetime: JoinApp.facetime.bundleIdentifier,
        )
    }

    public subscript(service: JoinLink.Service) -> String? {
        get {
            switch service {
            case .facetime:
                facetime

            case .jitsi:
                jitsi

            case .meet:
                meet

            case .other:
                other

            case .teams:
                teams

            case .zoom:
                zoom
            }
        }
        set {
            switch service {
            case .facetime:
                facetime = newValue

            case .jitsi:
                jitsi = newValue

            case .meet:
                meet = newValue

            case .other:
                other = newValue

            case .teams:
                teams = newValue

            case .zoom:
                zoom = newValue
            }
        }
    }
}
