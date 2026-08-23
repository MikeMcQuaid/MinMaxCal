import AppKit
import EventKit
import Foundation
import MinMaxCalDomain

/// Converts EventKit objects into Domain values; nothing EventKit leaves this module.
public enum EventKitDecoder {
    // MARK: Public

    /// A `CalendarList` for a calendar of the given kind.
    public static func list(_ calendar: EKCalendar, kind: ListKind) -> CalendarList {
        CalendarList(
            identifier: calendar.calendarIdentifier,
            title: calendar.title,
            colour: colour(calendar.color),
            kind: kind,
            accountName: calendar.source?.title ?? "",
        )
    }

    /// An `AgendaItem` for one event occurrence.
    public static func item(_ event: EKEvent, rules: MatchingRules) -> AgendaItem {
        let attendees = (event.attendees ?? []).map(attendee)
        let organiser = event.organizer.map(attendee)
        let member = MemberIdentity(
            calendarItemIdentifier: event.calendarItemIdentifier,
            occurrenceDate: event.occurrenceDate,
        )
        return AgendaItem(
            members: [member],
            kind: .event,
            title: event.title ?? "",
            start: event.startDate,
            inviteIdentifier: event.calendarItemExternalIdentifier,
            end: event.endDate,
            isAllDay: event.isAllDay,
            calendars: [list(event.calendar, kind: .event)],
            location: event.location,
            notes: event.notes,
            url: event.url,
            organiser: organiser,
            attendees: attendees,
            currentUserResponse: attendees.first(where: \.isCurrentUser)?.response,
            isAccepted: Acceptance.isAccepted(organiser: organiser, attendees: attendees),
            isCancelled: event.status == .canceled,
            joinLink: JoinLinkDetector.detect(
                url: event.url,
                location: event.location,
                notes: event.notes,
                rules: rules,
            ),
            recurrence: recurrence(event.recurrenceRules ?? []),
        )
    }

    /// An `AgendaItem` for a reminder, or nil when it has no due date.
    public static func item(_ reminder: EKReminder, rules: MatchingRules) -> AgendaItem? {
        guard let due = reminder.dueDateComponents, let start = (due.calendar ?? .current).date(from: due) else {
            return nil
        }

        return AgendaItem(
            members: [MemberIdentity(calendarItemIdentifier: reminder.calendarItemIdentifier)],
            kind: .reminder,
            title: reminder.title ?? "",
            start: start,
            isAllDay: due.hour == nil,
            calendars: [list(reminder.calendar, kind: .reminder)],
            location: reminder.location,
            notes: reminder.notes,
            url: reminder.url,
            isCompleted: reminder.isCompleted,
            joinLink: JoinLinkDetector.detect(
                url: reminder.url,
                location: reminder.location,
                notes: reminder.notes,
                rules: rules,
            ),
            recurrence: recurrence(reminder.recurrenceRules ?? []),
        )
    }

    // MARK: Private

    private static func attendee(_ participant: EKParticipant) -> Attendee {
        Attendee(
            name: AttendeeName.display(
                name: participant.name,
                email: participant.url.absoluteString.replacing("mailto:", with: ""),
            ),
            response: response(participant.participantStatus),
            isCurrentUser: participant.isCurrentUser,
        )
    }

    private static func recurrence(_ rules: [EKRecurrenceRule]) -> Recurrence? {
        guard let rule = rules.first else {
            return nil
        }

        let frequency: Recurrence.Frequency? =
            switch rule.frequency {
            case .daily:
                .daily

            case .weekly:
                .weekly

            case .monthly:
                .monthly

            case .yearly:
                .yearly

            @unknown default:
                nil
            }
        return frequency.map { Recurrence(frequency: $0, interval: rule.interval) }
    }

    private static func response(_ status: EKParticipantStatus) -> AttendeeResponse {
        switch status {
        case .accepted:
            .accepted

        case .declined:
            .declined

        case .pending:
            .pending

        case .tentative:
            .tentative

        case .completed,
             .delegated,
             .inProcess,
             .unknown:
            .unknown

        @unknown default:
            .unknown
        }
    }

    private static func colour(_ color: NSColor?) -> ListColour {
        guard let rgb = color?.usingColorSpace(.sRGB) else {
            return .grey
        }

        return ListColour(
            red: rgb.redComponent,
            green: rgb.greenComponent,
            blue: rgb.blueComponent,
            alpha: rgb.alphaComponent,
        )
    }
}
