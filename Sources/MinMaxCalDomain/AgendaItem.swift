import Foundation

public struct AgendaItem: Hashable, Identifiable, Sendable {
    // MARK: Lifecycle

    public init(
        members: [MemberIdentity],
        kind: ItemKind,
        title: String,
        start: Date,
        inviteIdentifier: String? = nil,
        end: Date? = nil,
        isAllDay: Bool = false,
        calendars: [CalendarList] = [],
        location: String? = nil,
        notes: String? = nil,
        url: URL? = nil,
        organiser: Attendee? = nil,
        attendees: [Attendee] = [],
        currentUserResponse: AttendeeResponse? = nil,
        isAccepted: Bool = true,
        isCancelled: Bool = false,
        isCompleted: Bool = false,
        joinLink: JoinLink? = nil,
    ) {
        self.members = members
        self.inviteIdentifier = inviteIdentifier
        self.kind = kind
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendars = calendars
        self.location = location
        self.notes = notes
        self.url = url
        self.organiser = organiser
        self.attendees = attendees
        self.currentUserResponse = currentUserResponse
        self.isAccepted = isAccepted
        self.isCancelled = isCancelled
        self.isCompleted = isCompleted
        self.joinLink = joinLink
    }

    // MARK: Public

    public var members: [MemberIdentity]
    public var inviteIdentifier: String?
    public var kind: ItemKind
    public var title: String
    public var start: Date
    public var end: Date?
    public var isAllDay: Bool
    public var calendars: [CalendarList]
    public var location: String?
    public var notes: String?
    public var url: URL?
    public var organiser: Attendee?
    public var attendees: [Attendee]
    public var currentUserResponse: AttendeeResponse?
    public var isAccepted: Bool
    public var isCancelled: Bool
    public var isCompleted: Bool
    public var joinLink: JoinLink?

    public var id: [MemberIdentity] {
        members
    }

    public var isTimed: Bool {
        isAllDay == false
    }

    public func hasEnded(at now: Date) -> Bool {
        guard let end else {
            return false
        }

        return end <= now
    }

    public func hasStarted(at now: Date) -> Bool {
        start <= now
    }
}
