@testable import MinMaxCalCoachingData
import Testing

@Test
func `hourly rollover splits audio without losing samples or reusing speaker identities`() throws {
    let session = DiarizationFixture()
    let diarizer = RollingDiarizer(session: session)
    try diarizer.process(Array(repeating: 1, count: 16_000), at: 3_599.5)
    let update = diarizer.snapshot()
    #expect(session.sampleCounts == [8_000, 8_000])
    #expect(session.resets == 1)
    #expect(session.finishes == 1)
    #expect(update.segments.map(\.speakerID) == ["speaker-1", "speaker-1@1"])
    #expect(update.segments.map(\.start) == [3_599.5, 3_600])
    #expect(update.segments.map(\.end) == [3_600, 3_600.5])
    #expect(update.activeSpeakerIDs == ["speaker-1@1"])
    #expect(diarizer.snapshot().segments == update.segments)
    try diarizer.process(Array(repeating: 1, count: 8_000), at: 3_600.5)
    #expect(diarizer.snapshot().segments.last?.end == 3_601)
    #expect(session.resets == 1)
    try diarizer.finish()
    #expect(session.finishes == 2)
    #expect(diarizer.snapshot().segments.count == 2)
}

@Test
func `late system audio and subsequent hours retain global timestamps and fresh labels`() throws {
    let session = DiarizationFixture()
    let diarizer = RollingDiarizer(session: session)
    try diarizer.process(Array(repeating: 1, count: 8_000), at: 7_199.75)
    let update = diarizer.snapshot()
    #expect(session.sampleCounts == [4_000, 4_000])
    #expect(update.segments.map(\.speakerID) == ["speaker-1@1", "speaker-1@2"])
    #expect(update.segments.map(\.start) == [7_199.75, 7_200])
    #expect(update.segments.map(\.end) == [7_200, 7_200.25])
    #expect(update.duration == 7_200.25)
}

// MARK: - DiarizationFixture
