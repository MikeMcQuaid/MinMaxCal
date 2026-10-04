import Foundation

public struct SyncContent: Codable, Equatable, Sendable {
    // MARK: Lifecycle

    public init(
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        availability: Availability = .busy,
        timeZone: String? = nil,
        location: String? = nil,
        url: URL? = nil,
        notes: String? = nil,
    ) {
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.availability = availability
        self.timeZone = timeZone
        self.location = location
        self.url = url
        self.notes = notes
    }

    // MARK: Public

    public enum Availability: String, Codable, Sendable {
        case busy
        case free
        case tentative
        case unavailable
        case unknown
    }

    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var availability: Availability
    public var timeZone: String?
    public var location: String?
    public var url: URL?
    public var notes: String?

    // MARK: Internal

    var availabilityForCopy: Availability {
        if availability == .unknown {
            .busy
        } else {
            availability
        }
    }
}
