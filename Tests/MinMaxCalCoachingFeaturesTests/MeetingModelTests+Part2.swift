import Foundation
import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import Testing

@Test
func `failed second start does not alter previous meeting`() async throws {
    let recorder = Recorder()
    let model = MeetingModel(
        recorder: recorder,
        store: Store(),
        speechModels: Models(),
    )
    await model.load()
    model.start()
    try await waitFor { model.phase == .recording }
    await model.stop()
    let previous = model.meetings
    recorder.failStart = true
    await model.load()
    model.start()
    try await waitFor { model.phase == .idle }
    #expect(model.meetings == previous)
}

@Test
func `start waits for speech model setup`() async {
    let model = MeetingModel(
        recorder: Recorder(),
        store: Store(),
        speechModels: Models(),
    )
    model.start()
    #expect(model.phase == .idle)
    #expect(model.current == nil)
    await model.stop()
}

@Test
func `only a completed model download enables start`() async throws {
    let models = Models(ready: false)
    let recorder = Recorder()
    let model = MeetingModel(
        recorder: recorder,
        store: Store(),
        speechModels: models,
    )
    #expect(model.canStart == false)
    await model.load()
    #expect(model.modelState == .missing)
    #expect(await models.downloads == 0)
    model.start()
    #expect(model.phase == .idle)
    model.downloadSpeechModels()
    model.downloadSpeechModels()
    #expect(model.canStart == false)
    #expect(model.modelState == .downloading)
    model.start()
    #expect(recorder.reduceSpeakerEcho == nil)
    try await waitFor { model.modelState == .ready }
    #expect(model.canStart)
    #expect(await models.downloads == 1)
    #expect(model.current == nil)
    model.start()
    try await waitFor { model.phase == .recording }
    #expect(model.canStart == false)
    await model.stop()
    #expect(model.canStart)
    let reopened = MeetingModel(
        recorder: Recorder(),
        store: Store(),
        speechModels: models,
    )
    await reopened.load()
    #expect(reopened.canStart)
    #expect(await models.downloads == 1)
}

@Test
func `failed model download keeps start disabled and can be retried`() async throws {
    let models = Models(
        ready: false,
        failDownload: true,
    )
    let model = MeetingModel(
        recorder: Recorder(),
        store: Store(),
        speechModels: models,
    )
    await model.load()
    model.downloadSpeechModels()
    try await waitFor { model.modelState == .missing }
    #expect(model.canStart == false)
    #expect(model.error != nil)
    await models.allowRetry()
    model.downloadSpeechModels()
    try await waitFor { model.modelState == .ready }
    #expect(model.canStart)
    #expect(model.error == nil)
}

@Test
func `cancelled model download cannot enable start`() async throws {
    let models = Models(
        ready: false,
        holdDownload: true,
    )
    let model = MeetingModel(
        recorder: Recorder(),
        store: Store(),
        speechModels: models,
    )
    await model.load()
    model.downloadSpeechModels()
    try await waitFor { model.downloadStatus == "Downloading test models…" }
    model.cancelModelDownload()
    await model.stop()
    #expect(model.modelState == .missing)
    #expect(model.canStart == false)
    #expect(model.error == nil)
    #expect(model.current == nil)
}

@Test
func `missing cached models after startup return to download setup`() async throws {
    let models = Models()
    let recorder = Recorder()
    recorder.failStart = true
    let model = MeetingModel(
        recorder: recorder,
        store: Store(),
        speechModels: models,
    )
    await model.load()
    #expect(model.canStart)
    await models.setReady(false)
    model.start()
    try await waitFor { model.phase == .idle }
    #expect(model.modelState == .missing)
    #expect(model.canStart == false)
    #expect(await models.downloads == 0)
}

@Test
func `calendar lookup suggests names and updates copied transcript after labelling`() async throws {
    let calendar = CalendarSource(events: [
        CalendarMeeting(
            id: "planning",
            title: "Weekly planning",
            calendarName: "Work",
            start: .now.addingTimeInterval(-60),
            end: .now.addingTimeInterval(1_800),
            participantNames: ["Alex", "Sam"],
            myName: "Mike",
            meetingURL: URL(string: "https://meet.jit.si/Planning"),
        ),
    ]) // swiftformat:disable:this trailingCommas - SwiftLint requires the comma.
    let recorder = Recorder()
    let store = Store()
    let model = MeetingModel(
        recorder: recorder,
        store: store,
        speechModels: Models(),
        calendar: calendar,
    )
    await model.load()
    await model.refreshCalendar(requestAccess: true)
    #expect(model.title == "Weekly planning")
    #expect(model.calendarMeeting?.participantNames == ["Alex", "Sam"])
    #expect(await calendar.accessRequests == 1)
    model.start()
    try await waitFor { model.phase == .recording }
    #expect(await calendar.accessRequests == 1)
    #expect(model.current?.title == "Weekly planning")
    #expect(model.current?.names["me"] == "Mike")
    #expect(model.current?.calendarParticipantNames == ["Alex", "Sam"])
    #expect(model.current?.names["speaker-1"] == nil)
    recorder.continuation?.yield(.init(
        segments: [.init(speakerID: "speaker-1", start: 0, end: 3)],
        duration: 3,
        transcript: [.init(text: "Hello.", start: 1, end: 2, source: .system)],
    ))
    try await waitFor { model.current?.duration == 3 }
    try await model.rename(speakerID: "speaker-1", to: "Sam", meetingID: #require(model.current?.id))
    #expect(model.current?.transcriptText == "[00:00:01] Sam: Hello.")
    await model.stop()
    #expect(await store.load().first?.calendarParticipantNames == ["Alex", "Sam"])
}

@Test
func `calendar refresh preserves custom titles and explicit event choices`() async { // swiftlint:disable:this function_body_length line_length - Complete scenario.
    let now = Date.now
    let first = CalendarMeeting(
        id: "first",
        title: "First",
        calendarName: "Work",
        start: now.addingTimeInterval(-60),
        end: now.addingTimeInterval(600),
        participantNames: ["Alex"],
        meetingURL: URL(string: "https://meet.jit.si/Planning"),
    )
    let second = CalendarMeeting(
        id: "second",
        title: "Second",
        calendarName: "Home",
        start: now.addingTimeInterval(120),
        end: now.addingTimeInterval(1_800),
        participantNames: ["Sam"],
        meetingURL: URL(string: "https://meet.jit.si/Planning"),
    )
    let calendar = CalendarSource(events: [second, first])
    let model = MeetingModel(
        recorder: Recorder(),
        store: Store(),
        speechModels: Models(),
        calendar: calendar,
    )
    await model.refreshCalendar(at: now)
    #expect(model.title == "First")
    model.selectCalendarMeeting("second")
    #expect(model.title == "Second")
    await model.refreshCalendar(at: now)
    #expect(model.calendarMeetingID == "second")
    model.title = "My own title"
    model.selectCalendarMeeting("first")
    await model.refreshCalendar(at: now)
    #expect(model.title == "My own title")
    model.selectCalendarMeeting(nil)
    await model.refreshCalendar(at: now)
    #expect(model.calendarMeeting == nil)
    #expect(model.title == "My own title")
    #expect(await calendar.accessRequests == 0)
    model.selectCalendarMeeting("first")
    await calendar.setFailure(true)
    await model.refreshCalendar(at: now)
    #expect(model.calendarMeeting == nil)
    await calendar.setFailure(false)
    await model.refreshCalendar(
        requestAccess: true,
        at: now,
    )
    #expect(model.calendarMeetingID == "first")
    #expect(model.title == "My own title")
}
