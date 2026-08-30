import Foundation

public struct JoinLink: Hashable, Sendable {
    // MARK: Lifecycle

    public init(service: Service, url: URL, appURL: URL? = nil) {
        self.service = service
        self.url = url
        self.appURL = appURL
    }

    // MARK: Public

    public enum Service: CaseIterable, Hashable, Sendable {
        case facetime
        case jitsi
        case meet
        case other
        case teams
        case zoom

        // MARK: Public

        public var name: String {
            switch self {
            case .facetime:
                "FaceTime"

            case .jitsi:
                "Jitsi"

            case .meet:
                "Google Meet"

            case .other:
                "Other links"

            case .teams:
                "Microsoft Teams"

            case .zoom:
                "Zoom"
            }
        }

        /// The service's own app, which takes its deep link, or nil when it has none.
        public var app: JoinApp? {
            switch self {
            case .facetime:
                .facetime

            case .teams:
                .teams

            case .zoom:
                .zoom

            case .jitsi,
                 .meet,
                 .other:
                nil
            }
        }
    }

    public var service: Service
    /// The web address, which any browser opens.
    public var url: URL
    /// The `zoommtg://` or `msteams://` deep link that takes the service's own app straight into the call.
    public var appURL: URL?
}
