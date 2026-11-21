@testable import MinMaxCalCoachingData
import MinMaxCalCoachingDomain
import Testing

@Test
func `speech ending before buffer delivery keeps its own interval`() {
    var activity = MicrophoneActivity()
    activity.update(true, at: 1.01)
    activity.update(false, at: 1.05)
    let intervals = activity.intervals(from: 1, to: 1.2)
    #expect(intervals == [1.01 ..< 1.05])
    var speech = MicrophoneSpeech(requiresVoiceActivity: true)
    for interval in intervals {
        speech.observe(start: interval.lowerBound, end: interval.upperBound, detected: true)
    }
    let word = TranscriptWord(text: "Yes", start: 1.02, end: 1.04, source: .microphone)
    #expect(speech.confirm([word]) == [word])
    #expect(speech.segments == [.init(speakerID: "me", start: 1.02, end: 1.04)])
    #expect(activity.intervals(from: 1.2, to: 1.4).isEmpty)
}

@Test
func `voice transitions preserve gaps and cross audio buffer boundaries`() {
    var activity = MicrophoneActivity()
    activity.update(true, at: 1)
    activity.update(true, at: 1.1)
    #expect(activity.intervals(from: 1, to: 1.2) == [1 ..< 1.2])
    activity.update(false, at: 1.25)
    activity.update(true, at: 1.3)
    activity.update(false, at: 1.35)
    #expect(activity.intervals(from: 1.2, to: 1.4) == [1.2 ..< 1.25, 1.3 ..< 1.35])
}
