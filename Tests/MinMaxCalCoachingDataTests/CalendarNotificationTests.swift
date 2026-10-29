import Foundation
@testable import MinMaxCalCoachingData
import MinMaxCalCoachingDomain
import Testing
import UserNotifications

@Test
@MainActor
func `calendar notifications target start time and never repeat a past occurrence`() throws {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let meeting = CalendarMeeting(
        id: "event/occurrence",
        title: "Planning",
        calendarName: "Work",
        start: now.addingTimeInterval(600),
        end: now.addingTimeInterval(1_800),
        participantNames: [],
        meetingURL: URL(string: "https://meet.jit.si/Planning"),
    )
    let request = try #require(TargetNotifications.meetingRequests(
        for: [meeting],
        at: now,
    )
    .first)
    #expect(request.content.categoryIdentifier == "coaching-meeting")
    #expect(request.content.userInfo["meetingID"] as? String == meeting.id)
    #expect(request.content.subtitle == meeting.title)
    #expect(request.content.sound == nil)
    let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
    #expect(trigger.repeats == false)
    #expect(trigger.dateComponents.timeZone == Calendar.current.timeZone)
    #expect(Calendar.current.date(from: trigger.dateComponents) == meeting.start)
    #expect(TargetNotifications.meetingRequests(
        for: [meeting],
        at: meeting.start,
    )
    .isEmpty)
    #expect(TargetNotifications.meetingRequests(
        for: [],
        at: now,
    )
    .isEmpty)
    let later = try #require(TargetNotifications.meetingRequests(
        for: [meeting],
        at: now.addingTimeInterval(60),
    )
    .first)
    #expect(later.identifier == request.identifier)
}

@Test
@MainActor
func `coaching registration preserves existing notification categories`() {
    let existing = UNNotificationCategory(identifier: "existing", actions: [], intentIdentifiers: [], options: [])
    let categories = TargetNotifications.categories(merging: [existing])
    #expect(categories.contains(existing))
    #expect(categories.map(\.identifier).sorted() == ["coaching-meeting", "existing"])
    #expect(TargetNotifications.categories(merging: categories).count == 2)
}

@Test(arguments: [
    (true, true, TimeInterval(600)),
    (false, false, TimeInterval(600)),
    (false, true, TimeInterval?.none),
])
@MainActor
func `manual-only meeting choices do not gain recording prompts`(
    allDay: Bool,
    conference: Bool,
    duration: TimeInterval?,
) {
    let now = Date.now
    let start = now.addingTimeInterval(600)
    let meeting = CalendarMeeting(
        id: "manual",
        title: "Manual choice",
        calendarName: "Work",
        start: start,
        end: duration.map { start.addingTimeInterval($0) },
        participantNames: [],
        meetingURL: URL(string: "https://example.com/call"),
        isAllDay: allDay,
        isConference: conference,
    )
    #expect(CalendarMeeting.inferred(from: [meeting], at: now) == [meeting])
    #expect(TargetNotifications.meetingRequests(for: [meeting], at: now).isEmpty)
    #expect(CalendarMeeting.suggestions(from: [meeting], at: now).isEmpty)
}
