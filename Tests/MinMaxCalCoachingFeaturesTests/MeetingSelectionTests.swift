import Foundation
import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import MinMaxCalDomain
import Testing

@Test
func `tomorrow's joinable events remain selectable beyond 24 hours`() async throws {
    let now = try #require(Calendar.current.date(from: DateComponents(year: 2_026, month: 10, day: 28, hour: 8)))
    let start = now.addingTimeInterval(36 * 3_600)
    let items = try ["https://meet.jit.si/Planning", "https://example.com/call"].enumerated().map { index, address in
        try AgendaItem(
            members: [.init(calendarItemIdentifier: String(1 - index))],
            kind: .event,
            title: "Meeting \(String(index))",
            start: start,
            end: start.addingTimeInterval(3_600),
            joinLink: JoinLinkDetector.classify(#require(URL(string: address))),
        )
    }
    let meetings = AgendaMeetingCalendar.meetings(in: Agenda(
        items: items,
        horizon: DateInterval(start: now, duration: 48 * 3_600),
    ))
    let recorder = Recorder()
    let notifier = Notifier()
    let model = MeetingModel(
        recorder: recorder,
        store: Store(),
        speechModels: Models(),
        calendar: CalendarSource(events: meetings),
        notifier: notifier,
    )
    await model.refreshCalendar(at: now)
    #expect(model.calendarMeetings.map(\.title) == items.map(\.title))
    #expect(notifier.scheduled == meetings.filter(\.canPrompt))
    for meeting in model.calendarMeetings {
        model.useCalendarMeeting(meeting.id)
        await model.refreshCalendar(at: now)
        #expect(model.calendarMeetingID == meeting.id)
        #expect(model.title == meeting.title)
    }
    #expect(model.phase == .idle)
    #expect(recorder.continuation == nil)
}
