@testable import MinMaxCalCoachingData
import MinMaxCalCoachingDomain

final class DiarizationFixture: DiarizationSession {
    var sampleCounts: [Int] = []
    var resets = 0
    var finishes = 0
    var duration = 0.0

    func process(_ samples: [Float]) {
        sampleCounts.append(samples.count)
        duration += Double(samples.count) / 16_000
    }

    func finish() {
        finishes += 1
    }

    func reset() {
        resets += 1
        duration = 0
    }

    func snapshot() -> SpeechUpdate {
        .init(
            segments: [.init(speakerID: "speaker-1", start: 0, end: duration)],
            duration: duration,
            activeSpeakerIDs: ["speaker-1"],
        )
    }
}
