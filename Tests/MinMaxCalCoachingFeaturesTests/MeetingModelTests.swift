import Foundation
import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import Testing

@Test
func `cancellation during preparation does not create A summary`() async {
    let recorder = Recorder()
    recorder.holdStart = true
    let model = MeetingModel(
        recorder: recorder,
        store: Store(),
        speechModels: Models(),
    )
    await model.load()
    model.start()
    await model.stop()
    #expect(model.phase == .idle)
    #expect(model.current == nil)
    #expect(model.meetings.isEmpty)
    #expect(model.error == nil)
}

@Test
func `own name persists and one to one inference labels every remote segment`() async throws { // swiftlint:disable:this function_body_length line_length - Complete scenario.
    let suite = "minmaxcal-coaching-tests-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let recorder = Recorder()
    let model = MeetingModel(
        recorder: recorder,
        store: Store(),
        speechModels: Models(),
        defaults: defaults,
    )
    await model.load()
    model.myName = "Mike"
    model.targetShare = 0.55
    model.turnLimit = 90
    model.title = "Scott / Mike"
    #expect(model.otherParticipantName == "Scott")
    model.start()
    try await waitFor { model.phase == .recording }
    recorder.continuation?.yield(.init(
        segments: [
            .init(speakerID: "speaker-2", start: 0, end: 3),
            .init(speakerID: "me", start: 4, end: 5),
        ],
        duration: 5,
        activeSpeakerIDs: ["speaker-2"],
        transcript: [
            .init(text: "Hello.", start: 1, end: 2, source: .system),
            .init(text: "Yes.", start: 4, end: 5, source: .microphone),
        ],
    ))
    try await waitFor { model.current?.duration == 5 }
    #expect(model.current?.segments.first?.speakerID == "speaker-1")
    #expect(model.activeSpeakerIDs == ["speaker-1"])
    #expect(model.current?.transcriptText == "[00:00:01] Scott: Hello.\n\n[00:00:04] Mike: Yes.")
    await model.stop()
    let reopened = MeetingModel(
        recorder: Recorder(),
        store: Store(),
        speechModels: Models(),
        defaults: defaults,
    )
    #expect(reopened.myName == "Mike")
    #expect(reopened.targetShare == 0.55)
    #expect(reopened.turnLimit == 90)
    model.otherParticipantName = ""
    model.start()
    try await waitFor { model.phase == .recording }
    #expect(model.current?.isOneToOne == false)
    await model.stop()
    model.title = "Sam / Mike"
    #expect(model.otherParticipantName == "Sam")
}

@Test
func `echo reduction can be disabled for headphones`() async throws {
    let recorder = Recorder()
    let model = MeetingModel(
        recorder: recorder,
        store: Store(),
        speechModels: Models(),
    )
    model.reduceSpeakerEcho = false
    await model.load()
    model.start()
    try await waitFor { model.phase == .recording }
    #expect(recorder.reduceSpeakerEcho == false)
    await model.stop()
}

@Test
func `unverified speech survives capture and saving`() async throws {
    let recorder = Recorder()
    let model = MeetingModel(
        recorder: recorder,
        store: Store(),
        speechModels: Models(),
    )
    await model.load()
    model.start()
    try await waitFor { model.phase == .recording }
    recorder.continuation?.yield(.init(
        segments: [.init(speakerID: "me", start: 0, end: 10)],
        duration: 20,
        transcript: [.init(text: "Hello.", start: 1, end: 2, source: .microphone)],
    ))
    try await waitFor { model.current?.duration == 20 }
    #expect(model.current?.hasUnverifiedSpeech == false)
    #expect(model.current?.transcriptText.contains("You: Hello.") == true)
    recorder.continuation?.yield(.init(
        segments: [
            .init(speakerID: "me", start: 0, end: 10),
            .init(speakerID: "unverified-microphone", start: 20, end: 30),
        ],
        duration: 30,
    ))
    try await waitFor { model.current?.duration == 30 }
    #expect(model.current?.hasUnverifiedSpeech == true)
    await model.stop()
    #expect(model.meetings.first?.hasUnverifiedSpeech == true)
}

func waitFor(_ condition: () -> Bool) async throws {
    for _ in 0 ..< 1_000 {
        if condition() {
            return
        }
        try await Task.sleep(for: .milliseconds(1))
    }
    Issue.record("Timed out waiting for model state")
}

@Test
func `stop saves final update and names`() async throws {
    let recorder = Recorder()
    let store = Store()
    let model = MeetingModel(
        recorder: recorder,
        store: store,
        speechModels: Models(),
    )
    await model.load()
    model.start()
    try await waitFor { model.phase == .recording }
    #expect(recorder.reduceSpeakerEcho == true)
    recorder.continuation?.yield(.init(
        segments: [.init(speakerID: "me", start: 0, end: 10)],
        duration: 20,
        transcript: [.init(text: "Hello.", start: 1, end: 2, source: .microphone)],
    ))
    try await waitFor { model.current?.duration == 20 }
    let id = try #require(model.current?.id)
    await model.rename(speakerID: "speaker-1", to: "Sam", meetingID: id)
    await model.rename(speakerID: "me", to: "Mike", meetingID: id)
    await model.stop()
    #expect(model.phase == .idle)
    #expect(model.meetings.count == 1)
    #expect(model.meetings.first?.isComplete == true)
    #expect(model.meetings.first?.names["speaker-1"] == "Sam")
    #expect(await store.load().first?.duration == 20)
    #expect(await store.load().first?.transcriptText == "[00:00:01] Mike: Hello.")
}

@Test
func `failure keeps partial summary`() async throws {
    let recorder = Recorder()
    let model = MeetingModel(
        recorder: recorder,
        store: Store(),
        speechModels: Models(),
    )
    await model.load()
    model.start()
    try await waitFor { model.phase == .recording }
    recorder.continuation?.yield(.init(
        segments: [],
        duration: 12,
    ))
    recorder.continuation?.finish(throwing: TestError.failed)
    try await waitFor { model.phase == .idle }
    #expect(model.meetings.first?.duration == 12)
    #expect(model.meetings.first?.isComplete == false)
    #expect(model.error != nil)
}
