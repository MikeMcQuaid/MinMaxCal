import Foundation
import MinMaxCalAgenda
import MinMaxCalCoachingDomain
import MinMaxCalDomain

nonisolated public final class AgendaMeetingCalendar: MeetingCalendar {
    // MARK: Lifecycle

    @preconcurrency
    @MainActor
    public init(agenda: AgendaModel) {
        read = {
            guard agenda.access.events == .full else {
                throw CocoaError(.userCancelled)
            }

            return Self.meetings(in: agenda.agenda)
        }
    }

    // MARK: Public

    public static func meetings(in agenda: Agenda) -> [CalendarMeeting] {
        agenda.items.compactMap { item in
            guard item.kind == .event,
                  let link = item.joinLink,
                  let id = id(for: item)
            else {
                return nil
            }

            let people = (item.attendees + [item.organiser].compactMap(\.self))
                .filter { $0.isPerson && $0.response != .declined }
            let names = people.filter { $0.isCurrentUser == false }.map(\.name)
            return CalendarMeeting(
                id: id,
                title: item.displayTitle,
                calendarName: item.calendars.map(\.title).joined(separator: ", "),
                start: item.start,
                end: item.end,
                participantNames: Array(Set(names)).sorted(),
                myName: people.first(where: \.isCurrentUser)?.name,
                meetingURL: link.url,
                isAllDay: item.isAllDay,
                isConference: link.isConference,
            )
        }
    }

    public static func id(for item: AgendaItem) -> String? {
        guard let member = item.members.first else {
            return nil
        }

        return """
        \(member.calendarItemIdentifier)/\
        \((member.occurrenceDate ?? item.start).timeIntervalSinceReferenceDate)/\
        \(item.start.timeIntervalSinceReferenceDate)
        """
    }

    public func meetings(
        around _: Date,
        requestAccess _: Bool,
    ) async throws -> [CalendarMeeting] {
        try await read()
    }

    // MARK: Private

    private let read: @MainActor @Sendable () throws -> [CalendarMeeting]
}
