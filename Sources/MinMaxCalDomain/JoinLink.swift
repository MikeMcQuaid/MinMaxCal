import Foundation

public struct JoinLink: Hashable, Sendable {
    // MARK: Lifecycle

    public init(service: Service, url: URL) {
        self.service = service
        self.url = url
    }

    // MARK: Public

    public enum Service: Hashable, Sendable {
        case jitsi
        case meet
        case other
        case zoom
    }

    public var service: Service
    public var url: URL

    public var app: JoinApp {
        switch service {
        case .zoom:
            .zoom

        case .jitsi,
             .meet:
            .edge

        case .other:
            .browser
        }
    }

    public var serviceName: String {
        switch service {
        case .jitsi:
            "Jitsi"

        case .meet:
            "Google Meet"

        case .other:
            "link"

        case .zoom:
            "Zoom"
        }
    }
}
