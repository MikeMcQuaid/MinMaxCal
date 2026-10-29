import Foundation
import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import Testing

@Test
func `meeting start refreshes stale calendar details and denial stays optional`() async throws {
    let calendar = CalendarSource(events: [
        CalendarMeeting(
            id: "old",
            title: "Old meeting",
            calendarName: "Work",
            start: .now.addingTimeInterval(-600),
            end: .now.addingTimeInterval(60),
            participantNames: ["Alex"],
            meetingURL: URL(string: "https://meet.jit.si/Planning"),
        ),
    ]) // swiftformat:disable:this trailingCommas - SwiftLint requires the comma.
    let model = MeetingModel(
        recorder: Recorder(),
        store: Store(),
        speechModels: Models(),
        calendar: calendar,
    )
    await model.load()
    await model.refreshCalendar()
    #expect(model.title == "Old meeting")
    await calendar.setEvents([])
    model.start()
    try await waitFor { model.phase == .recording }
    #expect(model.current?.title == "Meeting")
    #expect(model.current?.calendarParticipantNames == nil)
    await model.stop()
    await calendar.setFailure(true)
    await model.refreshCalendar(requestAccess: true)
    #expect(model.calendarMessage != nil)
    #expect(model.error == nil)
    #expect(model.canStart)
    model.title = "Manual meeting"
    model.start()
    try await waitFor { model.phase == .recording }
    #expect(model.current?.title == "Manual meeting")
    await model.stop()
}

@Test
func `a new calendar occurrence clears the previous other person override`() async {
    let now = Date.now
    let calendar = CalendarSource(events: [
        CalendarMeeting(
            id: "first",
            title: "Catch-up",
            calendarName: "Work",
            start: now.addingTimeInterval(-60),
            end: now.addingTimeInterval(600),
            participantNames: ["Scott"],
            myName: "Michael",
            meetingURL: URL(string: "https://meet.jit.si/Planning"),
        ),
    ]) // swiftformat:disable:this trailingCommas - SwiftLint requires the comma.
    let model = MeetingModel(
        recorder: Recorder(),
        store: Store(),
        speechModels: Models(),
        calendar: calendar,
    )
    model.myName = "Mike"
    await model.refreshCalendar(at: now)
    #expect(model.myName == "Mike")
    model.otherParticipantName = "Scott McKinnon"
    await model.refreshCalendar(at: now)
    #expect(model.otherParticipantName == "Scott McKinnon")
    await calendar.setEvents([
        CalendarMeeting(
            id: "second",
            title: "Catch-up",
            calendarName: "Work",
            start: now.addingTimeInterval(-60),
            end: now.addingTimeInterval(600),
            participantNames: ["Sam"],
            meetingURL: URL(string: "https://meet.jit.si/Planning"),
        ),
    ]) // swiftformat:disable:this trailingCommas - SwiftLint requires the comma.
    await model.refreshCalendar(at: now)
    #expect(model.otherParticipantName == "Sam")
}

@Test
func `target notifications run without a view and do not repeat while above target`() async throws {
    let recorder = Recorder()
    let notifier = Notifier()
    let model = MeetingModel(
        recorder: recorder,
        store: Store(),
        speechModels: Models(),
        notifier: notifier,
    )
    await model.load()
    model.start()
    try await waitFor { model.phase == .recording }
    #expect(notifier.requests == 1)
    recorder.continuation?.yield(.init(segments: [.init(speakerID: "me", start: 0, end: 20)], duration: 20))
    try await waitFor { model.current?.duration == 20 }
    #expect(notifier.messages.isEmpty)
    recorder.continuation?.yield(.init(segments: [.init(speakerID: "me", start: 0, end: 30)], duration: 30))
    try await waitFor { notifier.messages.count == 1 }
    for duration in [40.0, 60, 80] {
        recorder.continuation?.yield(.init(
            segments: [.init(speakerID: "me", start: 0, end: duration)],
            duration: duration,
        ))
        try await waitFor { model.current?.duration == duration }
    }
    #expect(notifier.messages.count == 1)
    recorder.continuation?.yield(.init(segments: [.init(speakerID: "speaker-1", start: 80, end: 400)], duration: 400))
    try await waitFor { model.current?.duration == 400 }
    recorder.continuation?.yield(.init(segments: [.init(speakerID: "me", start: 400, end: 460)], duration: 460))
    try await waitFor { notifier.messages.count == 2 }
    let cleared = notifier.clears
    await model.stop()
    #expect(notifier.clears > cleared)
    model.start()
    try await waitFor { model.phase == .recording }
    recorder.continuation?.yield(.init(segments: [.init(speakerID: "me", start: 0, end: 30)], duration: 30))
    try await waitFor { notifier.messages.count == 3 }
    await model.stop()
}

@Test
func `long turn notifications respect targets and suppress uncertain speech`() async throws {
    let recorder = Recorder()
    let notifier = Notifier()
    let model = MeetingModel(
        recorder: recorder,
        store: Store(),
        speechModels: Models(),
        notifier: notifier,
    )
    model.targetShare = 1
    model.turnLimit = 45
    await model.load()
    model.start()
    try await waitFor { model.phase == .recording }
    recorder.continuation?.yield(.init(segments: [.init(speakerID: "me", start: 0, end: 40)], duration: 40))
    try await waitFor { model.current?.duration == 40 }
    #expect(notifier.messages.isEmpty)
    recorder.continuation?.yield(.init(segments: [.init(speakerID: "me", start: 0, end: 45)], duration: 45))
    try await waitFor { notifier.messages.count == 1 }
    #expect(notifier.messages[0].contains("pause"))
    await model.stop()
    model.start()
    try await waitFor { model.phase == .recording }
    recorder.continuation?.yield(.init(
        segments: [
            .init(speakerID: "me", start: 0, end: 90),
            .init(speakerID: "unverified-microphone", start: 80, end: 90),
        ],
        duration: 90,
    ))
    try await waitFor { model.current?.duration == 90 }
    #expect(notifier.messages.count == 1)
    await model.stop()
}

@Test(arguments: [
    true,
    false,
])
func `notification denial or delivery failure does not stop recording`(denied: Bool) async throws {
    let recorder = Recorder()
    let notifier = Notifier()
    notifier.authorised = denied == false
    notifier.failDelivery = denied == false
    let model = MeetingModel(
        recorder: recorder,
        store: Store(),
        speechModels: Models(),
        notifier: notifier,
    )
    await model.load()
    model.start()
    try await waitFor { model.phase == .recording }
    recorder.continuation?.yield(.init(segments: [.init(speakerID: "me", start: 0, end: 90)], duration: 90))
    try await waitFor { model.current?.duration == 90 && model.notificationMessage != nil }
    #expect(model.error == nil)
    #expect(model.phase == .recording)
    #expect(notifier.messages.isEmpty)
    await model.stop()
}

@Test
func `ending a meeting does not notify for the final flushed speech`() async throws {
    let recorder = Recorder()
    recorder.finalUpdate = .init(segments: [.init(speakerID: "me", start: 0, end: 90)], duration: 90)
    let notifier = Notifier()
    let model = MeetingModel(
        recorder: recorder,
        store: Store(),
        speechModels: Models(),
        notifier: notifier,
    )
    await model.load()
    model.start()
    try await waitFor { model.phase == .recording }
    await model.stop()
    #expect(model.current?.duration == 90)
    #expect(notifier.messages.isEmpty)
}

@Test
func `upcoming meetings and reminders refresh without recording or overwriting my title`( // swiftlint:disable:this function_body_length line_length - Complete scenario.
) async throws {
    let now = Date.now
    let linked = CalendarMeeting(
        id: "later",
        title: "Afternoon call",
        calendarName: "Work",
        start: now.addingTimeInterval(3_600),
        end: now.addingTimeInterval(5_400),
        participantNames: ["Alex"],
        meetingURL: URL(string: "https://meet.jit.si/Planning"),
    )
    let calendar = CalendarSource(events: [
        linked,
        CalendarMeeting(
            id: "solo",
            title: "Focus time",
            calendarName: "Work",
            start: now,
            end: now.addingTimeInterval(600),
            participantNames: [],
        ),
    ])
    let notifier = Notifier()
    let model = MeetingModel(
        recorder: Recorder(),
        store: Store(),
        speechModels: Models(),
        calendar: calendar,
        notifier: notifier,
    )
    await model.load()
    #expect(model.calendarMeetings == [linked])
    #expect(model.calendarMeetingID == nil)
    #expect(model.phase == .idle)
    #expect(model.current == nil)
    #expect(notifier.scheduled == [linked])
    model.useCalendarMeeting(linked.id)
    #expect(model.title == linked.title)
    model.title = "My own title"
    await model.refreshCalendar(at: now)
    #expect(model.title == "My own title")
    model.calendarPromptsEnabled = false
    try await waitFor { notifier.scheduled.isEmpty }
    model.calendarPromptsEnabled = true
    try await waitFor { notifier.scheduled.isEmpty == false }
    model.start()
    try await waitFor { model.phase == .recording }
    #expect(notifier.scheduled.isEmpty)
    await model.refreshCalendar(at: now)
    #expect(model.calendarMeetings == [linked])
    #expect(notifier.scheduled.isEmpty)
    await model.stop()
    #expect(notifier.scheduled == [linked])
    await calendar.setEvents([])
    await model.refreshCalendar(at: now)
    #expect(notifier.scheduled.isEmpty)
}

@Test
func `record notification actions recheck the occurrence and require prepared models`() async throws {
    let now = Date.now
    let meeting = CalendarMeeting(
        id: "current",
        title: "Scott / Mike",
        calendarName: "Work",
        start: now.addingTimeInterval(-60),
        end: now.addingTimeInterval(600),
        participantNames: ["Scott"],
        myName: "Mike",
        meetingURL: URL(string: "https://meet.jit.si/Planning"),
    )
    let calendar = CalendarSource(events: [meeting])
    let models = Models(ready: false)
    let model = MeetingModel(
        recorder: Recorder(),
        store: Store(),
        speechModels: models,
        calendar: calendar,
    )
    await model.load()
    #expect(await model.recordCalendarMeeting("current", at: now) == false)
    #expect(model.phase == .idle)
    #expect(await models.downloads == 0)
    await models.setReady(true)
    let ready = MeetingModel(
        recorder: Recorder(),
        store: Store(),
        speechModels: models,
        calendar: calendar,
    )
    await ready.load()
    await calendar.setEvents([])
    #expect(await ready.recordCalendarMeeting("current", at: now) == false)
    #expect(ready.current == nil)
    await calendar.setEvents([meeting])
    ready.title = "Other meeting"
    #expect(await ready.recordCalendarMeeting("current", at: now))
    try await waitFor { ready.phase == .recording }
    #expect(ready.current?.title == "Scott / Mike")
    #expect(ready.current?.names["speaker-1"] == "Scott")
    #expect(await ready.recordCalendarMeeting("current", at: now) == false)
    await ready.stop()
}
