import Foundation

// MARK: - CalendarMeeting

public struct CalendarMeeting: Identifiable, Equatable, Sendable {
    // MARK: Lifecycle

    public init(
        id: String,
        title: String,
        calendarName: String,
        start: Date,
        end: Date?,
        participantNames: [String],
        myName: String? = nil,
        meetingURL: URL? = nil,
        isAllDay: Bool = false,
        isConference: Bool = true,
    ) {
        self.id = id
        self.title = title
        self.calendarName = calendarName
        self.start = start
        self.end = end
        self.participantNames = participantNames
        self.myName = myName
        self.meetingURL = meetingURL
        self.isAllDay = isAllDay
        self.isConference = isConference
    }

    // MARK: Public

    public let id: String
    public let title: String
    public let calendarName: String
    public let start: Date
    public let end: Date?
    public let participantNames: [String]
    public let myName: String?
    public let meetingURL: URL?
    public let isAllDay: Bool
    public let isConference: Bool

    public var canPrompt: Bool {
        isConference && isAllDay == false && (end.map { $0 > start } ?? false)
    }

    public static func inferred(
        from meetings: [Self],
        at date: Date,
    ) -> [Self] {
        meetings.filter { $0.meetingURL != nil && ($0.end.map { $0 > date } ?? true) }
            .sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    public static func suggestions(
        from meetings: [Self],
        at date: Date,
    ) -> [Self] {
        meetings
            // swiftlint:disable:next no_magic_numbers - Coaching durations in seconds.
            .filter { $0.canPrompt && $0.start <= date.addingTimeInterval(600) && ($0.end.map { $0 > date } ?? false) }
            .sorted { first, second in
                if (first.start <= date) != (second.start <= date) {
                    return first.start <= date
                }
                if first.start != second.start {
                    return abs(first.start.timeIntervalSince(date)) < abs(second.start.timeIntervalSince(date))
                }
                return first.id < second.id
            }
    }
}

// MARK: - MeetingCalendar
