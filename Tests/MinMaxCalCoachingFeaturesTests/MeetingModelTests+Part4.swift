import Foundation
import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import Testing

@Test
func `denying calendar access clears prompts without requesting notification permission`() async {
    let calendar = CalendarSource(events: [])
    await calendar.setFailure(true)
    let notifier = Notifier()
    let model = MeetingModel(
        recorder: Recorder(),
        store: Store(),
        speechModels: Models(),
        calendar: calendar,
        notifier: notifier,
    )
    await model.refreshCalendar(requestAccess: true)
    #expect(model.hasCalendarAccess == false)
    #expect(notifier.requests == 0)
    #expect(notifier.scheduled.isEmpty)
}
