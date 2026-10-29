import Foundation
@testable import MinMaxCalCoachingData
import Testing

@Test(
    .enabled(if: ProcessInfo.processInfo.environment["MINMAXCAL_TEST_COACHING_MODELS"] == "1"),
    arguments: [0.0, 8.0, 3_599.0],
)
func `synthetic audio runs through both models`(offset: Double) async throws {
    let processor = try await SpeechProcessor()
    for index in 0 ..< 12 {
        for microphone in [true, false] {
            try await processor.accept(AudioFrame(
                samples: Array(
                    repeating: 0,
                    count: 4_096,
                ),
                time: offset + Double(index * 4_096) / 16_000,
                isMicrophone: microphone,
            ))
        }
    }
    let update = try await processor.finish()
    #expect(abs(update.duration - offset - 3.072) < 0.001)
    #expect(update.microphoneLevel == 0)
    #expect(update.meetingLevel == 0)
    #expect(update.segments.allSatisfy { $0.start >= 0 && $0.end <= update.duration })
}
