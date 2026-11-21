import Foundation
@testable import MinMaxCalCoachingData
import MinMaxCalCoachingDomain
import Testing

struct MicrophoneSpeechTests {
    // MARK: Internal

    @Test
    func `grunts without recognised words do not count as speaking`() {
        var speech = MicrophoneSpeech(requiresVoiceActivity: true)
        speech.observe(start: 0, end: 5, detected: true)
        #expect(speech.confirm([]).isEmpty)
        #expect(speech.segments.isEmpty)
    }

    @Test
    func `playback words without microphone voice activity are rejected`() {
        var speech = MicrophoneSpeech(requiresVoiceActivity: true)
        speech.observe(start: 0, end: 5, detected: false)
        #expect(speech.confirm([word(start: 1, end: 2)]).isEmpty)
        #expect(speech.segments.isEmpty)
    }

    @Test
    func `delayed words confirm only the overlapping microphone activity`() {
        var speech = MicrophoneSpeech(requiresVoiceActivity: true)
        speech.observe(start: 1, end: 2, detected: true)
        speech.observe(start: 2, end: 3, detected: true)
        speech.observe(start: 3, end: 10, detected: false)
        let words = [word(start: 0.5, end: 1.5), word(start: 1.5, end: 3.5), word(start: 8, end: 9)]
        #expect(speech.confirm(words) == Array(words.prefix(2)))
        #expect(speech.segments == [SpeechSegment(speakerID: "me", start: 1, end: 3)])
    }

    @Test
    func `remote transcript words survive without becoming microphone speech`() {
        var speech = MicrophoneSpeech(requiresVoiceActivity: true)
        speech.observe(start: 0, end: 5, detected: true)
        let remote = TranscriptWord(text: "Remote", start: 1, end: 2, source: .system)
        #expect(speech.confirm([remote]) == [remote])
        #expect(speech.segments.isEmpty)
    }

    @Test
    func `separate voice intervals and overlapping word timings are not double counted`() {
        var speech = MicrophoneSpeech(requiresVoiceActivity: true)
        speech.observe(start: 1, end: 2, detected: true)
        speech.observe(start: 4, end: 5, detected: true)
        _ = speech.confirm([word(start: 0, end: 4.5), word(start: 4, end: 6)])
        #expect(speech.segments == [
            SpeechSegment(speakerID: "me", start: 1, end: 2),
            SpeechSegment(speakerID: "me", start: 4, end: 5),
        ])
    }

    @Test
    func `headphone fixtures can confirm words without a hardware detector`() {
        var speech = MicrophoneSpeech(requiresVoiceActivity: false)
        let words = [word(start: 1, end: 2)]
        #expect(speech.confirm(words) == words)
        #expect(speech.segments == [SpeechSegment(speakerID: "me", start: 1, end: 2)])
    }

    // MARK: Private

    private func word(start: Double, end: Double) -> TranscriptWord {
        TranscriptWord(text: "Hello", start: start, end: end, source: .microphone)
    }
}
