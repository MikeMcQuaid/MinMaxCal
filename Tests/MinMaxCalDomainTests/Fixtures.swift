import Foundation
import MinMaxCalDomain

enum Fixtures {
    static let now: Date = .init(timeIntervalSinceReferenceDate: 800_000_040)
    static let work: CalendarList = .init(
        identifier: "work",
        title: "Work",
        colour: .grey,
        kind: .event,
        accountName: "Work",
    )
    static let team: CalendarList = .init(
        identifier: "team",
        title: "Team",
        colour: .grey,
        kind: .event,
        accountName: "Work",
    )
    static let home: CalendarList = .init(
        identifier: "home",
        title: "Home",
        colour: .grey,
        kind: .event,
        accountName: "iCloud",
    )
    static let list: CalendarList = .init(
        identifier: "list",
        title: "Reminders",
        colour: .grey,
        kind: .reminder,
        accountName: "iCloud",
    )

    static func event(
        _ identifier: String,
        title: String = "Event",
        invite: String? = nil,
        startingIn minutes: Double = 30,
        duration: Double = 30,
        calendar: CalendarList = work,
        attendees: [Attendee] = [],
        isAccepted: Bool = true,
        isAllDay: Bool = false,
    ) -> AgendaItem {
        let start = now.addingTimeInterval(minutes * 60)
        return AgendaItem(
            members: [MemberIdentity(calendarItemIdentifier: identifier, occurrenceDate: start)],
            kind: .event,
            title: title,
            start: start,
            inviteIdentifier: invite,
            end: start.addingTimeInterval(duration * 60),
            isAllDay: isAllDay,
            calendars: [calendar],
            attendees: attendees,
            currentUserResponse: attendees.first(where: \.isCurrentUser)?.response,
            isAccepted: isAccepted,
        )
    }

    static func reminder(
        _ identifier: String,
        title: String = "Reminder",
        dueIn minutes: Double = 30,
        isAllDay: Bool = false,
    ) -> AgendaItem {
        AgendaItem(
            members: [MemberIdentity(calendarItemIdentifier: identifier)],
            kind: .reminder,
            title: title,
            start: now.addingTimeInterval(minutes * 60),
            isAllDay: isAllDay,
            calendars: [list],
        )
    }

    static func agenda(_ items: [AgendaItem]) -> Agenda {
        Agenda(items: items.sorted { $0.start < $1.start }, horizon: DateInterval(start: now, duration: 48 * 60 * 60))
    }
}
