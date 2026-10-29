import Foundation
import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import Testing

@Test
func `an interrupted recording keeps its transcript in saved history`() async throws {
    let recorder = Recorder()
    let store = Store()
    let model = MeetingModel(recorder: recorder, store: store, speechModels: Models())
    await model.load()
    model.start()
    try await waitFor { model.phase == .recording }
    let transcript = [TranscriptWord(text: "Saved words.", start: 0, end: 1, source: .microphone)]
    recorder.continuation?.yield(.init(segments: [], duration: 1, transcript: transcript))
    try await waitFor { model.current?.duration == 1 }
    recorder.continuation?.finish(throwing: TestError.failed)
    try await waitFor { model.phase == .idle }
    let saved = try #require(await store.load().first)
    #expect(saved.transcript == transcript)
    #expect(saved.isComplete == false)
    #expect(saved.notice == model.error)
    #expect(model.displayedError == nil)
    let reopened = MeetingModel(recorder: Recorder(), store: store, speechModels: Models())
    await reopened.load()
    #expect(reopened.meetings.first?.transcript == transcript)
}

@Test
func `a saved recording warning appears only once for the selected meeting`() {
    var meeting = Meeting(title: "Planning")
    meeting.notice = "The one-hour model limit was reached."
    let model = MeetingModel(recorder: Recorder(), store: Store(), speechModels: Models())
    model.meetings = [meeting]
    model.selectedID = meeting.id
    model.error = meeting.notice
    #expect(model.displayedError == nil)
    model.selectedID = nil
    #expect(model.displayedError == meeting.notice)
    model.selectedID = meeting.id
    model.error = "Could not export the summary."
    #expect(model.displayedError == "Could not export the summary.")
}

@Test
func `the speaker reset countdown repeats hourly and disappears after stopping`() async throws {
    let recorder = Recorder()
    let model = MeetingModel(recorder: recorder, store: Store(), speechModels: Models())
    await model.load()
    #expect(model.recordingTimeRemaining == nil)
    model.start()
    try await waitFor { model.phase == .recording }
    #expect(model.recordingTimeRemaining == 3_600)
    recorder.continuation?.yield(.init(segments: [], duration: 3_599))
    try await waitFor { model.current?.duration == 3_599 }
    #expect(model.recordingTimeRemaining == 1)
    recorder.continuation?.yield(.init(segments: [], duration: 3_601))
    try await waitFor { model.current?.duration == 3_601 }
    #expect(model.recordingTimeRemaining == 3_599)
    await model.stop()
    #expect(model.recordingTimeRemaining == nil)
}

@Test
func `deleting a failed recording clears its warning and saved selection`() async {
    let store = Store()
    var meeting = Meeting(title: "Interrupted")
    meeting.notice = "Audio analysis could not keep up."
    meeting.transcript = [.init(text: "Saved words.", start: 0, end: 1, source: .microphone)]
    await store.save(meeting)
    let model = MeetingModel(recorder: Recorder(), store: store, speechModels: Models())
    await model.load()
    model.current = meeting
    model.selectedID = meeting.id
    model.error = meeting.notice
    await model.delete(meeting)
    #expect(model.current == nil)
    #expect(model.selectedID == nil)
    #expect(model.selected == nil)
    #expect(model.error == nil)
    #expect(model.displayedError == nil)
    #expect(await store.load().isEmpty)
    await model.deactivate()
}
