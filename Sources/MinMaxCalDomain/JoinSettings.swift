/// The app each call service's links open in, by bundle identifier; nil is the default browser.
public struct JoinSettings: Codable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(zoom: String? = nil, meet: String? = nil, jitsi: String? = nil, other: String? = nil) {
        self.zoom = zoom
        self.meet = meet
        self.jitsi = jitsi
        self.other = other
    }

    // MARK: Public

    public static let `default`: Self = .init(
        zoom: JoinApp.zoom.bundleIdentifier,
        meet: JoinApp.edge.bundleIdentifier,
        jitsi: JoinApp.edge.bundleIdentifier,
    )

    public var zoom: String?
    public var meet: String?
    public var jitsi: String?
    public var other: String?

    public subscript(service: JoinLink.Service) -> String? {
        get {
            switch service {
            case .jitsi:
                jitsi

            case .meet:
                meet

            case .other:
                other

            case .zoom:
                zoom
            }
        }
        set {
            switch service {
            case .jitsi:
                jitsi = newValue

            case .meet:
                meet = newValue

            case .other:
                other = newValue

            case .zoom:
                zoom = newValue
            }
        }
    }
}
