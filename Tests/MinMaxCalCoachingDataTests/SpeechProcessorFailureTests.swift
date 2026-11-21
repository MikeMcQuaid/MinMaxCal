@testable import MinMaxCalCoachingData
import MinMaxCalCoachingDomain
import Testing

@Test(arguments: [false, true])
func `partial snapshots keep microphone words when another source fails`(finishing: Bool) async throws {
    let microphone = SpeechSessionFixture(results: SpeechResults(), appendError: nil)
    let system = SpeechSessionFixture(results: SpeechResults(), appendError: nil)
    let processor = SpeechProcessor(
        diarizer: DiarizationFixture(),
        transcriber: LiveTranscriber(microphone: microphone, system: system),
        reduceSpeakerEcho: true,
    )
    try await processor.accept(.init(
        samples: Array(repeating: 0, count: 3_200),
        time: 1,
        isMicrophone: true,
        microphoneActivity: [1 ..< 1.2],
    ))
    let word = TranscriptWord(text: "Yes", start: 1.01, end: 1.05, source: .microphone)
    await microphone.publish(SpeechResults(words: [word]))
    await system.publish(SpeechResults(failure: RecordingError.interrupted))
    await #expect(throws: RecordingError.interrupted) {
        if finishing {
            _ = try await processor.finish()
        } else {
            try await processor.accept(.init(samples: [], time: 1.2, isMicrophone: true))
        }
    }
    let partial = await processor.snapshot()
    #expect(partial.transcript == [word])
    #expect(partial.segments.contains(.init(speakerID: "me", start: 1.01, end: 1.05)))
}
