import Foundation
@testable import MinMaxCalCoachingData
import MinMaxCalCoachingDomain
import Testing

@Test
func `watchdog timeout survives cancellation and keeps finalised words`() {
    let word = TranscriptWord(text: "Hello", start: 1, end: 2, source: .microphone)
    var results = SpeechResults(words: [word])
    results.timedOut = true
    results.failure = CancellationError()
    let drained = results.consume()
    #expect(drained.words == [word])
    #expect(drained.error as? RecordingError == .recognitionTimedOut)
    #expect(results.consume().words.isEmpty)
    #expect(results.error as? RecordingError == .recognitionTimedOut)
}

@Test
func `ordinary recognition failures and successful drains retain their meaning`() {
    var failed = SpeechResults(failure: CancellationError())
    #expect(failed.consume().error is CancellationError)
    var successful = SpeechResults()
    #expect(successful.consume().error == nil)
}
