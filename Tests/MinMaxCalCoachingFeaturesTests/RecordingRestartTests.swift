import Foundation
import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import Testing

@Test
func `restart preserves the partial recording and uses its context after the agenda changes`() async throws {
    let recorder = Recorder()
    let store = Store()
    let calendar = CalendarSource(events: [])
    let model = MeetingModel(recorder: recorder, store: store, speechModels: Models(), calendar: calendar)
    await model.load()
    model.title = "Planning"
    model.myName = "Mike"
    model.otherParticipantName = "Sam"
    model.start()
    try await waitFor { model.phase == .recording }
    let transcript = [TranscriptWord(text: "Saved words.", start: 0, end: 1, source: .microphone)]
    recorder.continuation?.yield(.init(segments: [], duration: 1, transcript: transcript))
    try await waitFor { model.current?.duration == 1 }
    recorder.continuation?.finish(throwing: TestError.failed)
    try await waitFor { model.canRestart }
    let partial = try #require(model.current)
    #expect(recorder.starts == 1)

    model.title = "Next meeting"
    model.myName = "New default"
    model.otherParticipantName = "Alex"
    let next = CalendarMeeting(
        id: "next",
        title: "Next meeting",
        calendarName: "Work",
        start: .now,
        end: .now.addingTimeInterval(600),
        participantNames: ["Alex"],
        meetingURL: URL(string: "https://zoom.us/j/123456789"),
    )
    await calendar.setEvents([next])
    model.restart()
    model.restart()
    try await waitFor { model.phase == .recording }
    let restarted = try #require(model.current)
    #expect(recorder.starts == 2)
    #expect(restarted.id != partial.id)
    #expect(restarted.title == partial.title)
    #expect(restarted.names == partial.names)
    #expect(restarted.isOneToOne == partial.isOneToOne)
    #expect(restarted.calendarParticipantNames == partial.calendarParticipantNames)
    #expect(model.calendarMeetingID == nil)
    #expect(model.calendarMeetings == [next])
    #expect(restarted.transcript?.isEmpty == true)
    #expect(model.error == nil)
    #expect(model.canRestart == false)
    #expect(await store.load().contains(partial))
    await model.stop()
    #expect(model.canRestart == false)
    #expect(await store.load().count == 2)
    await model.deactivate()
}

@Test
func `restart waits for cleanup and refuses completed or disabled recordings`() async {
    let recorder = Recorder()
    let model = MeetingModel(recorder: recorder, store: Store(), speechModels: Models())
    await model.load()
    var meeting = Meeting(title: "Partial")
    model.meetings = [meeting]
    model.selectedID = meeting.id
    #expect(model.canRestart)
    model.recordingTask = Task {}
    #expect(model.canStart == false)
    #expect(model.canRestart == false)
    model.restart()
    #expect(recorder.starts == 0)
    model.recordingTask = nil
    meeting.isComplete = true
    model.meetings = [meeting]
    #expect(model.canRestart == false)
    model.restart()
    #expect(recorder.starts == 0)
    meeting.isComplete = false
    model.meetings = [meeting]
    await model.deactivate()
    #expect(model.canRestart == false)
    model.restart()
    #expect(recorder.starts == 0)
}
