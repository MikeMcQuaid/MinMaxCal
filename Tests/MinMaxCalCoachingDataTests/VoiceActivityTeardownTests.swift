@testable import MinMaxCalCoachingData
import Testing

@Test
func `queued voice callbacks cannot read a device after teardown`() throws {
    let frames = AsyncThrowingStream<AudioFrame, any Error>.makeStream()
    let output = AudioOutput(continuation: frames.continuation, epoch: 0)
    output.stopVoiceActivityUpdates()
    try output.updateVoiceActivity(
        { () throws -> Bool in throw RecordingError.interrupted }(),
        hostTime: 0,
    )
    frames.continuation.finish()
}
