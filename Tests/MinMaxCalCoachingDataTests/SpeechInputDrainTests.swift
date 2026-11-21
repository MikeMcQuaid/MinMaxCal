import AVFoundation
@testable import MinMaxCalCoachingData
import Testing

@Test
@available(macOS 27, *)
func `ending converted audio emits the resampling tail once`() throws {
    let format = try #require(AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 44_100, channels: 1, interleaved: false,
    ))
    let input = try SpeechInput(format: format)
    let first = try #require(try input.input(samples: Array(repeating: 0.25, count: 3_200), at: 10))
    let tail = try input.finish()
    #expect(tail.isEmpty == false)
    #expect(first.bufferStartTime?.seconds == 10)
    #expect(tail.allSatisfy { $0.bufferStartTime == nil })
    let duration = first.bufferDuration.seconds + tail.reduce(0) { $0 + $1.bufferDuration.seconds }
    #expect(abs(duration - 0.2) <= 1 / 44_100)
    #expect(try input.finish().isEmpty)
}

@Test
@available(macOS 27, *)
func `a short first chunk retains its clock when output arrives during the drain`() throws {
    let format = try #require(AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 44_100, channels: 1, interleaved: false,
    ))
    let input = try SpeechInput(format: format)
    let live = try input.input(samples: [0.25], at: 10)
    let buffers = try (live.map { [$0] } ?? []) + (input.finish())
    #expect(buffers.first?.bufferStartTime?.seconds == 10)
    #expect(buffers.dropFirst().allSatisfy { $0.bufferStartTime == nil })
}
