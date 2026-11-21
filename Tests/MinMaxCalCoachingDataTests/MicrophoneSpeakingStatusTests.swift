@testable import MinMaxCalCoachingData
import Testing

@Test(arguments: [false, true])
func `microphone status uses intervals or levels according to echo reduction`(reduceSpeakerEcho: Bool) async throws {
    let processor = SpeechProcessor(
        diarizer: DiarizationFixture(),
        transcriber: LiveTranscriber(
            microphone: SpeechSessionFixture(results: SpeechResults(), appendError: nil),
            system: SpeechSessionFixture(results: SpeechResults(), appendError: nil),
        ),
        reduceSpeakerEcho: reduceSpeakerEcho,
    )
    try await processor.accept(.init(samples: Array(repeating: 0.1, count: 3_200), time: 1, isMicrophone: true))
    #expect(await processor.snapshot().activeSpeakerIDs.contains("me") == !reduceSpeakerEcho)
    #expect(await processor.snapshot().segments.contains(where: { $0.speakerID == "me" }) == false)
    for (time, level) in [(1.2, Float.zero), (1.4, Float(0.0001))] {
        try await processor.accept(.init(
            samples: Array(repeating: level, count: 3_200),
            time: time,
            isMicrophone: true,
        ))
        #expect(await processor.snapshot().activeSpeakerIDs.contains("me") == false)
    }
    try await processor.accept(.init(
        samples: Array(repeating: 0, count: 3_200),
        time: 1.6,
        isMicrophone: true,
        microphoneActivity: [1.6 ..< 1.8],
    ))
    #expect(await processor.snapshot().activeSpeakerIDs.contains("me") == reduceSpeakerEcho)
    #expect(try await processor.finish().activeSpeakerIDs.contains("me") == false)
}
