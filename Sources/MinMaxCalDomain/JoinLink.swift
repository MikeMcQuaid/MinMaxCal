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

    /// Whether this detector-vetted URL identifies a conference rather than a generic web page.
    public var isConference: Bool {
        guard url.user() == nil, let host = url.host()?.lowercased() else {
            return false
        }

        let parts = url.pathComponents.dropFirst()
        switch service {
        case .facetime,
             .teams,
             .zoom:
            return true

        case .meet:
            return parts.first?.wholeMatch(of: /[a-z]{3}-[a-z]{4}-[a-z]{3}/) != nil
                // swiftlint:disable:next no_magic_numbers - Conference path components.
                || (parts.first == "lookup" && parts.count >= 2)

        case .jitsi:
            return parts.isEmpty == false

        case .other:
            if ["zoom.us", "zoomgov.com"].contains(where: { host == $0 || host.hasSuffix(".\($0)") }) {
                // swiftlint:disable:next no_magic_numbers - Conference path components.
                return parts.count >= 2 && ["j", "my", "s"].contains(parts.first)
            }
            if host == "whereby.com" {
                return parts.isEmpty == false
            }
            return host.hasSuffix(".webex.com") && (url.path().hasPrefix("/meet/")
                || url.path().hasPrefix("/join/") || url.path().hasSuffix("/j.php"))
        }
    }
}
