import Foundation

public struct MemberIdentity: Codable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(calendarItemIdentifier: String, occurrenceDate: Date? = nil) {
        self.calendarItemIdentifier = calendarItemIdentifier
        self.occurrenceDate = occurrenceDate
    }

    // MARK: Public

    public var calendarItemIdentifier: String
    public var occurrenceDate: Date?
}
