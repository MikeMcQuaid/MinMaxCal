import MinMaxCalCoachingDomain
import SwiftUI

// MARK: - UpcomingMeetingsView

struct UpcomingMeetingsView: View {
    // MARK: Internal

    let model: MeetingModel

    var body: some View {
        if model.hasCalendarAccess {
            let meetings = CalendarMeeting.inferred(
                from: model.calendarMeetings,
                at: model.calendarNow,
            )
            VStack(
                alignment: .leading,
                // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                spacing: 8,
            ) {
                Text("Upcoming meetings").font(.subheadline.bold())
                if meetings.isEmpty {
                    Text("No events with a Join button today or tomorrow.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                section("Today", meetings: meetings.filter { calendar.isDateInTomorrow($0.start) == false })
                section("Tomorrow", meetings: meetings.filter { calendar.isDateInTomorrow($0.start) })
            }
        }
    }

    // MARK: Private

    @Environment(\.calendar)
    private var calendar

    @ViewBuilder
    private func section(_ title: String, meetings: [CalendarMeeting]) -> some View {
        if meetings.isEmpty == false {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            ForEach(meetings) { meeting in row(meeting) }
        }
    }

    private func row(_ meeting: CalendarMeeting) -> some View {
        MeetingChoiceRow(
            meeting: meeting,
            selected: meeting.id == model.calendarMeetingID,
        ) {
            model.useCalendarMeeting(meeting.id)
        }
        .disabled(model.phase != .idle)
    }
}

// MARK: - MeetingChoiceRow
