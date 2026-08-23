import Foundation

public extension AgendaItem {
    enum Sample: CaseIterable, Hashable, Sendable {
        case zoomEvent
        case meetEvent
        case jitsiEvent
        case plainEvent
        case reminder

        // MARK: Public

        public var name: String {
            switch self {
            case .zoomEvent:
                "Event with a Zoom call"

            case .meetEvent:
                "Event with a Google Meet call"

            case .jitsiEvent:
                "Event with a Jitsi call"

            case .plainEvent:
                "Event with no call"

            case .reminder:
                "Reminder"
            }
        }

        public func item(now: Date) -> AgendaItem {
            let start = now.addingTimeInterval(Self.leadTime)
            switch self {
            case .zoomEvent:
                return event(start: start, title: "Weekly planning", link: Self.zoomTestLink)

            case .meetEvent:
                return event(start: start, title: "Design review", link: Self.meetLink)

            case .jitsiEvent:
                return event(start: start, title: "Community call", link: Self.jitsiLink)

            case .plainEvent:
                return event(start: start, title: "Lunch with Sam", link: nil)

            case .reminder:
                return AgendaItem(
                    members: [MemberIdentity(calendarItemIdentifier: "sample-reminder")],
                    kind: .reminder,
                    title: "Submit expenses",
                    start: start,
                    calendars: [Self.remindersList],
                    notes: "Receipts are in the shared folder: https://example.com/expenses",
                )
            }
        }

        // MARK: Private

        private static let leadTime: TimeInterval = 60
        private static let duration: TimeInterval = 1_800
        private static let zoomTestLink: JoinLink = .init(service: .zoom, url: literal("https://zoom.us/test"))
        private static let meetLink: JoinLink = .init(service: .meet, url: literal("https://meet.google.com"))
        private static let jitsiLink: JoinLink = .init(service: .jitsi, url: literal("https://meet.jit.si"))
        private static let workCalendar: CalendarList = .init(
            identifier: "sample-work",
            title: "Work",
            colour: .blue,
            kind: .event,
            accountName: "Work",
        )
        private static let teamCalendar: CalendarList = .init(
            identifier: "sample-team",
            title: "Team",
            colour: .orange,
            kind: .event,
            accountName: "Work",
        )
        private static let remindersList: CalendarList = .init(
            identifier: "sample-reminders",
            title: "Reminders",
            colour: .red,
            kind: .reminder,
            accountName: "iCloud",
        )

        private static func literal(_ url: StaticString) -> URL {
            // swiftlint:disable:next force_unwrapping - the sample links are fixed, valid literals
            URL(string: String(describing: url))!
        }

        private func event(start: Date, title: String, link: JoinLink?) -> AgendaItem {
            AgendaItem(
                members: [MemberIdentity(calendarItemIdentifier: "sample-\(title)", occurrenceDate: start)],
                kind: .event,
                title: title,
                start: start,
                end: start.addingTimeInterval(Self.duration),
                calendars: [Self.workCalendar, Self.teamCalendar],
                location: "Boardroom, 4th floor",
                notes: "Agenda and pre-reading: https://example.com/agenda\n\nPlease review before we meet.",
                url: link?.url,
                organiser: Attendee(name: "Alex Morgan", response: .accepted),
                attendees: [
                    Attendee(name: "Alex Morgan", response: .accepted),
                    Attendee(name: "You", response: .accepted, isCurrentUser: true),
                    Attendee(name: "Priya Patel", response: .tentative),
                    Attendee(name: "Jordan Lee", response: .pending),
                ],
                currentUserResponse: .accepted,
                joinLink: link,
            )
        }
    }
}
