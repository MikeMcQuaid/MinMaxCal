import EventKit
import Foundation
import MinMaxCalDomain

extension EventKitDecoder {
    /// Captures identity, eligibility and mirrored fields without passing EventKit objects out.
    public static func syncEvent(_ event: EKEvent) -> SyncEvent {
        let item = item(event)
        return SyncEvent(
            identity: SyncIdentity(
                calendar: event.calendar.calendarIdentifier,
                item: event.calendarItemIdentifier,
                event: event.eventIdentifier ?? event.calendarItemIdentifier,
                external: event.calendarItemExternalIdentifier,
                occurrence: event.hasRecurrenceRules || event.isDetached ? event.occurrenceDate : nil,
            ),
            content: SyncContent(
                title: event.title ?? "",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                availability: availability(event.availability),
                timeZone: event.timeZone?.identifier,
                location: event.location,
                url: event.url,
                notes: event.notes,
            ),
            isAccepted: item.isAccepted,
            response: item.currentUserResponse,
            isCancelled: item.isCancelled,
            hasAttendees: event.hasAttendees,
            hasAlarms: event.hasAlarms,
        )
    }

    static func availability(_ value: EKEventAvailability) -> SyncContent.Availability {
        switch value {
        case .busy:
            .busy

        case .free:
            .free

        case .tentative:
            .tentative

        case .unavailable:
            .unavailable

        default:
            .unknown
        }
    }

    static func apply(_ content: SyncContent, to event: EKEvent) {
        event.title = content.title
        event.startDate = content.start
        event.endDate = content.end
        event.isAllDay = content.isAllDay
        event.timeZone = content.timeZone.flatMap(TimeZone.init(identifier:))
        event.location = content.location
        event.url = content.url
        event.notes = content.notes
        event.alarms = []
        switch content.availability {
        case .busy:
            event.availability = .busy

        case .free:
            event.availability = .free

        case .tentative:
            event.availability = .tentative

        case .unavailable:
            event.availability = .unavailable

        case .unknown:
            event.availability = .busy
        }
    }
}
