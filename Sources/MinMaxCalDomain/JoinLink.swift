import Foundation

public struct JoinLink: Hashable, Sendable {
    // MARK: Lifecycle

    public init(service: Service, url: URL, zoomURL: URL? = nil) {
        self.service = service
        self.url = url
        self.zoomURL = zoomURL
    }

    // MARK: Public

    public enum Service: CaseIterable, Hashable, Sendable {
        case jitsi
        case meet
        case other
        case zoom

        // MARK: Public

        public var name: String {
            switch self {
            case .jitsi:
                "Jitsi"

            case .meet:
                "Google Meet"

            case .other:
                "Other links"

            case .zoom:
                "Zoom"
            }
        }
    }

    public var service: Service
    /// The web address, which any browser opens.
    public var url: URL
    /// The `zoommtg://` deep link that takes the Zoom app straight into the meeting.
    public var zoomURL: URL?
}
