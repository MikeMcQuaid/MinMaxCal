@testable import MinMaxCalCoachingData
import MinMaxCalCoachingDomain
import Testing

@Test(arguments: [false, true])
func `a failed system drain preserves final microphone words exactly once`(finishing: Bool) async {
    let word = TranscriptWord(text: "Hello", start: 1, end: 2, source: .microphone)
    let transcriber = LiveTranscriber(
        microphone: SpeechSessionFixture(results: SpeechResults(words: [word]), appendError: nil),
        system: SpeechSessionFixture(results: SpeechResults(failure: RecordingError.interrupted), appendError: nil),
    )
    let result = finishing
        ? await transcriber.finish()
        : await transcriber.accept([], isMicrophone: true, time: 2)
    #expect(result.words == [word])
    #expect(result.error as? RecordingError == .interrupted)
    #expect(await transcriber.accept([], isMicrophone: true, time: 2).words.isEmpty)
}

@Test
func `an append failure still delivers both sources pending words`() async {
    let words = [
        TranscriptWord(text: "Hello", start: 1, end: 2, source: .microphone),
        TranscriptWord(text: "Hi", start: 1, end: 2, source: .system),
    ]
    let transcriber = LiveTranscriber(
        microphone: SpeechSessionFixture(
            results: SpeechResults(words: [words[0]]),
            appendError: RecordingError.audioOverrun,
        ),
        system: SpeechSessionFixture(results: SpeechResults(words: [words[1]]), appendError: nil),
    )
    let result = await transcriber.accept([0], isMicrophone: true, time: 2)
    #expect(result.words == words)
    #expect(result.error as? RecordingError == .audioOverrun)
}

@Test
func `both successful sources deliver each word once`() async {
    let words = [
        TranscriptWord(text: "Hello", start: 1, end: 2, source: .microphone),
        TranscriptWord(text: "Hi", start: 1, end: 2, source: .system),
    ]
    let transcriber = LiveTranscriber(
        microphone: SpeechSessionFixture(results: SpeechResults(words: [words[0]]), appendError: nil),
        system: SpeechSessionFixture(results: SpeechResults(words: [words[1]]), appendError: nil),
    )
    let result = await transcriber.accept([0], isMicrophone: true, time: 2)
    #expect(result.words == words)
    #expect(result.error == nil)
    #expect(await transcriber.finish().words.isEmpty)
}
